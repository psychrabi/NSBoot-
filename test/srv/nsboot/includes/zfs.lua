zfs = {
    mtab = function(p_args)
        local fd_file, fd_data
        fd_file = io.open("/etc/mtab", "r");
        fd_data = fd_file:read("*a");
        fd_file:close();
        if string.find(fd_data, p_args) ~= nil then
            return true
        else
            return false;
        end
    end,
    snap = function(p_data)
        return os.execute("/usr/sbin/zfs snap " .. p_data .. " 2>/dev/null");
    end,
    unsnap = function(p_data)
        return os.execute("/usr/sbin/zfs destroy -f " .. p_data .. " 2>/dev/null");
    end,
    mount = function(p_data, p_point)
        return os.execute("/usr/bin/mount -t zfs " .. p_data .. " " .. p_point .. " 2>>/var/log/messages");
    end,
    unmount = function(p_point)
        return os.execute("/usr/bin/umount -f " .. p_point .. " 2>/dev/null");
    end
};
return zfs;