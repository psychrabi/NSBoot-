nsboot.inc.checkconf = function(p_test)
    local result = true
    if nsboot.cfg == nil then
        result = false
    end
    if nsboot.cfg ~= nil then
        if nsboot.cfg.server == nil then
            result = false
        end
        if nsboot.cfg.iscsi == nil then
            result = false
        end
        if nsboot.cfg.iscsi.iqn == nil then
            result = false
        end
        if nsboot.cfg.iscsi.listen == nil then
            result = false
        end
        if nsboot.cfg.iscsi.port == nil then
            result = false
        end
        if nsboot.cfg.iscsi.proto == nil then
            result = false
        end
        if nsboot.cfg.dhcp == nil then
            result = false
        end
        if nsboot.cfg.dhcp.config == nil then
            result = false
        end
        if nsboot.cfg.dhcp.config.global == nil then
            result = false
        end
        if nsboot.cfg.server.vendor == nil then
            result = false
        end
        if nsboot.cfg.server.version == nil then
            result = false
        end
        if nsboot.cfg.server.ipv4 == nil then
            result = false
        end
        if nsboot.cfg.server.mask == nil then
            result = false
        end
        if nsboot.cfg.server.gateway == nil then
            result = false
        end
        if nsboot.cfg.server.dns1 == nil then
            result = false
        end
        if nsboot.cfg.server.dns2 == nil then
            result = false
        end
        if nsboot.cfg.server.workdir == nil then
            result = false
        end
        if nsboot.cfg.server.tftp == nil then
            result = false
        end
        if nsboot.cfg.server.distdir == nil then
            result = false
        end
        if nsboot.cfg.server.imgdir == nil then
            result = false
        end
        if nsboot.cfg.server.imgdatadir == nil then
            result = false
        end
        if nsboot.cfg.server.imgbackdir == nil then
            result = false
        end
        if nsboot.cfg.server.config == nil then
            result = false
        end
        if nsboot.cfg.wks == nil then
            result = false
        end
        if nsboot.cfg.dhcp.port == nil then
            result = false
        end
        if nsboot.cfg.dhcp.workdir == nil then
            result = false
        end
        if nsboot.cfg.tftp.port == nil then
            result = false
        end
        if nsboot.cfg.tftp.workdir == nil then
            result = false
        end
        if nsboot.cfg.server.image_prefix == nil then
            result = false
        end
        if nsboot.cfg.server.nbd_nbds == nil then
            result = false
        end
        if nsboot.cfg.server.nbd_max_part == nil then
            result = false
        end
    end
    return result
end;
nsboot.inc.debug = function(t_data)
    -- if t_data ~= nil then  io.open("/tmp/debug.nsboot","a"):write(t_data,"\n"):close() end;
end;
nsboot.inc.lsof = function(p_patern)
    if os.execute("/usr/bin/lsof " .. p_patern .. " 2>/dev/null") ~= nil then
        local fd;
        fd = io.popen("/usr/bin/lsof " .. p_patern .. " 2>/dev/null");
        return (#fd:read("a*") > 0);
    else
        return false;
    end

end;
nsboot.inc.lsofkill = function(p_path)
    nsboot.inc.debug("TUT 0")
    if os.execute("/usr/bin/lsof -t " .. p_path .. " 2>/dev/null") ~= nil then
        local fd;
        fd = io.popen("/usr/bin/kill -9 $(/usr/bin/lsof -t " .. p_path .. ") 2>/dev/null");
        return (#fd:read("a*") > 0);
    else
        return false;
    end

end;
nsboot.inc.search_nbd = function()
    for i_index = 1, nsboot.cfg.server.nbd_nbds, 1 do
        nsboot.inc.debug("TUT 2")
        if os.execute("/usr/bin/lsof /dev/nbd" .. i_index .. " 2>/dev/null | /usr/bin/wc -l") ~= nil then
            local fd;
            fd = io.popen("/usr/bin/lsof /dev/nbd" .. i_index .. " 2>/dev/null | /usr/bin/wc -l");
            if tonumber(fd:read("a*")) == 0 then
                return ("/dev/nbd" .. i_index);
            end
        else
            return false;
        end
    end
end;

nsboot.inc.getpid_nbd = function(t_path)
    local result
    if t_path ~= nil and nsboot.inc.isFile(t_path) then
        if os.execute("/usr/bin/lsof -t " .. t_path .. " 2>/dev/null") ~= nil then

            local fd;
            fd = io.popen("/usr/bin/lsof -t " .. t_path .. " 2>/dev/null ");
            result = (fd:read("a*"));
            if result == '' then
                return nil
            else
                return result
            end
        else
            return nil
        end
    end
    result = nil
end;

nsboot.inc.getdev_nbd = function(t_pid)
    local result
    if t_pid ~= nil and
        os.execute(
            "/usr/bin/lsof -p " .. t_pid:gsub('%W', '') ..
                " 2>/dev/null |  /usr/bin/awk '/\\/dev\\/nbd/ { print $NF }' ") then
        local fd;
        fd = io.popen("/usr/bin/lsof -p " .. t_pid:gsub('%W', '') ..
                          " 2>/dev/null |  /usr/bin/awk '/\\/dev\\/nbd/ { print $NF }' ");
        result = fd:read("a*");
        if result == '' then
            return nil
        else
            return result
        end
    else
        return nil;
    end
end;

nsboot.inc.scCheck = function()
    local result = true
    if nsboot.inc.checkconf then
        if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.dhcp.port) then
            result = false
        end
        if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.tftp.port) then
            result = false
        end
        if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.iscsi.port) then
            result = false
        end
    end
    return result
end;
nsboot.inc.systemctl = function(p_name, p_cmd)
    return os.execute("/usr/bin/systemctl " .. p_cmd .. " " .. p_name)
end;
nsboot.inc.monit = function()
    ngx.say("MONIT")
    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.dhcp.port) then
        nsboot.inc.systemctl("isc-dhcp-server", "start");
        nsboot.inc.systemctl("isc-dhcp-server", "restart");
    end
    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.tftp.port) then
        nsboot.inc.systemctl("isc-dhcp-server", "start");
        nsboot.inc.systemctl("tftpd-hpa", "restart");
    end
    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.iscsi.port) then
        nsboot.inc.systemctl("isc-dhcp-server", "start");
        nsboot.inc.systemctl("tgt", "restart");
    end
end;
nsboot.inc.GetMacFromIPv4 = function(p_ipv4)
    if nsboot.inc.checkconf() and p_ipv4 ~= nil then
        local i, v
        for i, v in pairs(nsboot.cfg.wks) do
            if p_ipv4 == v.ipv4 then
                if v.mac ~= nil then
                    return v.mac;
                end
            end
        end
        i, v = nil, nil
    end
end;
nsboot.inc.GetIDFromIPv4 = function(p_ipv4)
    if nsboot.inc.checkconf() and p_ipv4 ~= nil then
        local i, v
        for i, v in pairs(nsboot.cfg.wks) do
            if p_ipv4 == v.ipv4 then
                return i;
            end
        end
        i, v = nil, nil
    end
end;

nsboot.inc.unescape = function(s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return s
end
function nsboot.inc.isDir(name)
    local lfs = require("lfs")
    if type(name) ~= "string" then
        return false
    end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end
function nsboot.inc.isFile(name)
    if name ~= nil and nsboot.lib.posix.stat(name) ~= nil then
        return true
    else
        return false
    end
    -- note that the short evaluation is to
    -- return false instead of a possible nil

    return false
end

function nsboot.inc.isFileOrDir(name)
    if type(name) ~= "string" then
        return false
    end
    return os.rename(name, name) and true or false
end
function nsboot.inc.isSupperMode(id)
    if nsboot.inc.checkconf() and tostring(nsboot.cfg.wks[tonumber(id)].supper) ~= nil and
        tostring(nsboot.cfg.wks[tonumber(id)].supper) == "1" then
        return true
    else
        return false
    end
end
function nsboot.inc.ls_files(path)
    if nsboot.inc.isDir(path) then
        local result, t_res = {}
        iter, dir_obj = lfs.dir(path)
        while true do
            t_res = dir_obj:next();
            if t_res ~= nil then
                if lfs.attributes(path .. "/" .. t_res).mode == "file" then
                    table.insert(result, t_res)
                end
            else
                break
            end
        end
        dir_obj:close()
        t_res = nil
        return result
    else
        return "none"
    end
end
function nsboot.inc.ls_devices(path)
    if nsboot.inc.isDir(path) then
        local result, t_res = {}
        iter, dir_obj = lfs.dir(path)
        while true do
            t_res = dir_obj:next();
            if t_res ~= nil then
                if lfs.attributes(path .. "/" .. t_res).mode == "block device" then
                    if string.find(t_res, '@') ~= nil or string.find(t_res, '-') ~= nil then
                    else
                        table.insert(result, t_res)
                    end
                end
            else
                break
            end
        end
        dir_obj:close()
        t_res = nil
        return result
    else
        return "none"
    end
end
function nsboot.inc.isMacARP(p_ip)
    local f_tmp, f_mac, f_data = os.tmpname()
    os.execute("/usr/sbin/arp -a " .. p_ip .. " | /usr/bin/awk '{ print $4 }' > " .. f_tmp)
    f_mac = io.open(f_tmp, "r")
    f_data = f_mac:read("*a")
    f_mac:close()
    os.remove(f_tmp)
    return f_data
end