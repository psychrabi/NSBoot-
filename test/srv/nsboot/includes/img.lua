img = {
    new = function(p_path, p_size)
        return os.execute(
            "/usr/bin/qemu-img -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on encryption=off " ..
                p_path .. " " .. p_size);
    end,
    child = function(p_parrent, p_child)
        return os.execute("/usr/bin/qemu-img create -f qcow2 -b " .. p_parrent .. " " .. p_child ..
                              " -o lazy_refcounts=on 2>>/tmp/result ");
    end,
    del = function(p_image)
        return os.remove(p_image);
    end,
    commit = function(p_image)
        local fd;
        fd = io.popen("/usr/bin/qemu-img commit " .. p_image);
    end,
    used = function(p_image)
        if os.execute("/usr/bin/lsof " .. p_image .. " 2>/dev/null") ~= nil then
            local fd;
            fd = io.popen("/usr/bin/lsof -t " .. p_image .. " 2>/dev/null");
            return (#fd:read("a*") > 0);
        else
            return false;
        end
    end
};
return img;