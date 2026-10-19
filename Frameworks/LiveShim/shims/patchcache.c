/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LiveShim/patchcache.h>
#include <LiveShim/vroot.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <errno.h>
#include <os/lock.h>
#include <mach/mach.h>
#include <mach/task_info.h>
#include <mach/vm_region.h>
#include <mach-o/dyld_images.h>
#include <sys/stat.h>
#include <ptrauth.h>
#include <string.h>

uint64_t patchcache[kDyldPtrCount];

static bool g_have_ptrcache = false;
static os_unfair_lock g_lock = OS_UNFAIR_LOCK_INIT;

static bool patchcache_region_has_protection(uint64_t address, vm_prot_t protection,
                                            mach_vm_size_t requiredSize)
{
    if(address == 0 || address > UINT64_MAX - requiredSize)
    {
        return false;
    }

    vm_address_t regionAddress = (vm_address_t)address;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t regionInfo = {0};
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName = MACH_PORT_NULL;
    kern_return_t kr = vm_region_64(mach_task_self(), &regionAddress, &regionSize,
                                    VM_REGION_BASIC_INFO_64,
                                    (vm_region_info_t)&regionInfo, &infoCount,
                                    &objectName);
    if(objectName != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), objectName);
    }

    return kr == KERN_SUCCESS && regionAddress <= address &&
           address - regionAddress <= regionSize &&
           requiredSize <= regionSize - (address - regionAddress) &&
           (regionInfo.protection & protection) == protection;
}

static bool patchcache_current_shared_cache(uintptr_t *baseOut, uint8_t uuidOut[16])
{
    struct task_dyld_info dyldInfo = {0};
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if(task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&dyldInfo, &count) != KERN_SUCCESS ||
       dyldInfo.all_image_info_addr == 0)
    {
        return false;
    }

    const struct dyld_all_image_infos *infos =
        (const struct dyld_all_image_infos *)(uintptr_t)dyldInfo.all_image_info_addr;
    if(infos->version < 15 || infos->sharedCacheBaseAddress == 0)
    {
        return false;
    }

    *baseOut = (uintptr_t)infos->sharedCacheBaseAddress;
    memcpy(uuidOut, infos->sharedCacheUUID, 16);
    return true;
}

bool ksurface_user_patchcache_load(void)
{
    os_unfair_lock_lock(&g_lock);
    if(g_have_ptrcache)
    {
        os_unfair_lock_unlock(&g_lock);
        return true;
    }
    
    const char *rootPath = liveshim_vroot();
    if(!rootPath)
    {
        os_unfair_lock_unlock(&g_lock);
        return false;
    }
    
    char path[PATH_MAX];
    snprintf(path, PATH_MAX, "%s/boot/patchfinder.bin", rootPath);
    int fd = open(path, O_RDONLY);
    if(fd < 0)
    {
        os_unfair_lock_unlock(&g_lock);
        return false;
    }
    
    struct stat st;
    if(fstat(fd, &st) != 0 || st.st_size != sizeof(ksurface_patchcache_file_t))
    {
        close(fd);
        os_unfair_lock_unlock(&g_lock);
        return false;
    }

    ksurface_patchcache_file_t file = {0};
    size_t done = 0;
    while(done < sizeof(file))
    {
        ssize_t n = read(fd, (char *)&file + done, sizeof(file) - done);
        if(n > 0)
        {
            done += (size_t)n;
            continue;
        }
        if(n < 0 && errno == EINTR)
        {
            continue;
        }
        close(fd);
        os_unfair_lock_unlock(&g_lock);
        return false;
    }

    close(fd);

    uintptr_t sharedCacheBase = 0;
    uint8_t sharedCacheUUID[16] = {0};
    if(file.magic != KSURFACE_PATCHCACHE_MAGIC ||
       file.version != KSURFACE_PATCHCACHE_VERSION ||
       file.pointer_count != kDyldPtrCount ||
       !patchcache_current_shared_cache(&sharedCacheBase, sharedCacheUUID) ||
       memcmp(file.shared_cache_uuid, sharedCacheUUID, sizeof(sharedCacheUUID)) != 0)
    {
        os_unfair_lock_unlock(&g_lock);
        return false;
    }

    uint64_t rebased[kDyldPtrCount];
    for(size_t i = 0; i < kDyldPtrCount; i++)
    {
        if(file.offsets[i] == 0 || file.offsets[i] > UINTPTR_MAX - sharedCacheBase)
        {
            os_unfair_lock_unlock(&g_lock);
            return false;
        }

        rebased[i] = sharedCacheBase + file.offsets[i];
        bool isCodeAddress = i <= kDyldPtrOpenat || i >= kDyldExpandPathFunc;
        mach_vm_size_t requiredSize = i == kDyldLockUnlockFunc ? 2 * sizeof(uintptr_t) : sizeof(uintptr_t);
        vm_prot_t protection = isCodeAddress ? VM_PROT_EXECUTE : VM_PROT_READ;
        if(!patchcache_region_has_protection(rebased[i], protection, requiredSize))
        {
            os_unfair_lock_unlock(&g_lock);
            return false;
        }

        if(!isCodeAddress)
        {
            uint64_t target = 0;
            memcpy(&target, (const void *)(uintptr_t)rebased[i], sizeof(target));
            target = (uint64_t)(uintptr_t)ptrauth_strip((void *)(uintptr_t)target,
                                                        ptrauth_key_function_pointer);
            if(!patchcache_region_has_protection(target, VM_PROT_EXECUTE, 1))
            {
                os_unfair_lock_unlock(&g_lock);
                return false;
            }
        }
    }

    memcpy(patchcache, rebased, sizeof(rebased));
    
    g_have_ptrcache = true;
    os_unfair_lock_unlock(&g_lock);
    return true;
}
