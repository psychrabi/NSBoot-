nbd = {
    mod = function(p_max_part, p_nbds)
        return os.execute("/usr/sbin/modprobe nbd max_part " .. p_max_part .. " nbds " .. p_nbds);
    end,
    unmod = function()
        return os.execute("/usr/sbin/modprobe -r nbd");
    end,
    add = function(p_dev, p_path, p_flags)
        os.execute("/srv/nsboot/client.lua " .. p_dev .. " " .. p_path .. " " .. p_flags);
        tmpfile = io.open("/tmp/debug", "w")
        tmpfile:write(
            "/srv/nsboot/client.lua /usr/bin/qemu-nbd '--connect=" .. p_dev .. " " .. p_path .. " --pid-file=" .. p_path ..
                ".pid " .. p_flags .. "'")
        tmpfile:close()
    end,
    del = function(p_dev)
        return os.execute("/usr/bin/qemu-nbd -d " .. p_dev .. " 2>/dev/null");
    end,
    kill = function(p_pid)
        return os.execute("/usr/bin/kill -9 ", p_pid);
    end,
    used = function(p_dev)
        if p_dev ~= nil and os.execute("/usr/bin/lsof -t " .. p_dev .. " 2>/dev/null") ~= nil then
            local fd;
            fd = io.popen("/usr/bin/lsof -t " .. p_dev .. " 2>/dev/null");
            return (#fd:read("a*") > 0);
        else
            return false
        end
    end,
    usewho = function(p_dev)
        local fd;
        if os.execute("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep qemu-nbd)\"  2>/dev/null") ~=
            nil then
            fd =
                io.popen("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep qemu-nbd)\"  2>/dev/null"); ---
            if fd ~= nil and (#fd:read("a*") > 0) then
                return 1
            end
        else
            return false;
        end---
        if os.execute("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep tgtd)\" 2>/dev/null") ~= nil then
            fd = io.popen("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep tgtd)\" 2>/dev/null"); ---
            if fd ~= nil and (#fd:read("a*") > 0) then
                return 2
            end
        else
            return false;
        end
    end
};

return nbd;