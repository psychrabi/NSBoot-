---#!/usr/bin/lua
-- tgtadm --lld iscsi --op new --mode target --tid 1 -T 											#CREATE TARGET
-- lld iscsi --op new --mode target --tid --lun 													#ADD LUN
-- tgtadm --lld iscsi --op new --mode logicalunit --tid 1 --lun 1 -b /dev/nbd1 					#ADD LUN
-- lld iscsi --op delete --force --mode logicalunit --tid --lun 									#REMOVE LUN
-- tgtadm --lld iscsi --op show --mode target 													#SHOW TARGET
-- lld iscsi --op delete --force --mode target --tid                                            	#REMOVE TARGET FORCE
-- lsof -i TCP@0.0.0.0:3260 																		#ибо — скомбинировать все эти ключи
-- lsof -i :68 																					#Например, отобразить сервисы, прослушивающие порт 22 и/или уже установленные соединения на этом порту:
-- tostring
--[[             INSTALL COMPONENTS                ]] -- apt install etherwake shellinabox qemu-utils lua-json lua-socket lua-posix nginx-extras
--[[   

				_____________________________________________________________________
				[																	]
				[                 CREATE NEW WORKSTATION 							]
				---------------------------------------------------------------------
				|																	|
				|   ENABLE 					[X] 									|
				|   TARGET ID 				[1-500 \/] 								|
				|	HOSTNAME 				[                                    ]  |
				|   GROUP 					[ DEFAULT 						  \/ ]  |
				| ----------------------------------------------------------------- |	
				|	IP ADDRESS 				[                                    ]  |
				|   MAC ADDRESS 			[                                    ]  |
				|   GATEWAY 				[                                    ]  |
				|   DNS SERVERS 			[                                    ]  |
				|   DOMAIN SEARCH			[                                    ]  |	
				| ----------------------------------------------------------------- |
				|   IMAGE [selectid] SELECT [ IMG 1 [IMG 1]/[IMG 2]/[IMG 3]   \/ ]  |
				|   IMAGE [selectid] TYPE 	[device/iso/disk 				  \/ ]  |		
 				|   IMAGE [selectid] NAME	[ 									 ] 	|			
 				|   IMAGE [selectid] ENABLE	[X] 									|
				|   IMAGE [selectid] CACHE 	[none/unsafe/writeback 			  \/ ]  |
				| ----------------------------------------------------------------- |
				|   SELECT BOOT 1 			[                                 \/ ]  |
				|   SELECT BOOT 2 			[  NONE                           \/ ]  |
				|   SELECT BOOT 3 			[  NONE                           \/ ]  |
				|   PXE FILE 				[  ipxe 							 ]  |
				|   HARDWARE PROFILE 		[  NONE 							 ]  |
				|--------------------------------------------------------------------

 ]] --
--[[#>
	[[=============================================================================================================================================================================================]] nsboot =
    {}
nsboot.cmd = {}
nsboot.lib = {}
nsboot.inc = {}
nsboot.web = {}
nsboot.bin = {}
nsboot.cfg = dofile("/srv/nsboot/cfg/cfg.lua").cfg

-- -- Debug function to inspect a table structure
-- function dump(o)
--     if type(o) ~= 'table' then
--        return tostring(o)
--     end

--     local s = '{ '
--     for k,v in pairs(o) do
--        if type(k) ~= 'number' then
--           k = '"'..k..'"'
--        end
--        s = s .. '['..k..'] = ' .. dump(v) .. ', '
--     end
--     return s .. '} '
--  end

--  -- Log the structure of the config
--  ngx.log(ngx.ERR, "nsboot.cfg structure: " .. dump(nsboot))
--[[===========================================================================================================================================================================================]]
--[[ TARGET COMMANDS sets opt1,opt2,opt3  ]]
--[[===========================================================================================================================================================================================]]

nsboot.lib.json = require("cjson");
nsboot.lib.lfs = require("lfs");
nsboot.lib.posix = require("posix");
--[[ TARGET COMMANDS sets opt1,opt2,opt3  ]]
--[[===========================================================================================================================================================================================]]
nsboot.cmd.tgt = {
    new = function(opt, p_tid)
        return
            os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op new --mode target --tid " .. p_tid .. " -T " .. opt);
    end, -- CREATE TARGET
    destroy = function(opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op delete --mode target --tid " .. opt);
    end, -- REMOVE TARGET
    kill = function(opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op delete --force --mode target --tid " .. opt);
    end, -- FORCE REMOVE TARGET
    show = function(opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op show --mode target " .. opt);
    end, -- INFO TARGETS
    rules = function(p_tid, opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --mode target --op bind --tid " .. p_tid .. " -I " ..
                              opt);
    end, -- ALLOW CLIENT IP
    unrul = function(p_tid, opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --mode target --op unbind --tid " .. p_tid .. " -I " ..
                              opt);
    end,
    used = function(p_tgt)
        local fd; ---
        if os.execute(
            "/usr/sbin/tgtadm --lld iscsi --op show --mode target | /usr/bin/grep --color \"Target [0-9]:\" | /usr/bin/grep " ..
                p_tgt) ~= nil then
            fd = io.popen(
                "/usr/sbin/tgtadm --lld iscsi --op show --mode target | /usr/bin/grep --color \"Target [0-9]:\" | /usr/bin/grep " ..
                    p_tgt); ---
            return (#fd:read("a*") > 0);
        else
            return false;
        end
    end
}; ---
nsboot.cmd.lun = { ---
    add = function(p_tid, p_lun, p_dev)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op new --mode logicalunit --tid " .. p_tid ..
                              " --lun " .. p_lun .. " -b " .. p_dev);
    end,
    del = function(p_tid, p_lun)
        return os.execute("sudo -n /usr/sbin/tgtadm --lld iscsi --op delete --mode logicalunit --tid " .. p_tid ..
                              " --lun " .. p_lun);
    end,
    stop = function(p_opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --offline " .. p_opt);
    end,
    start = function(p_opt)
        return os.execute("sudo -n /usr/sbin/tgtadm --ready " .. p_opt);
    end
}; ---
nsboot.cmd.nbd = {
    mod = function(p_max_part, p_nbds)
        return os.execute("sudo -n /usr/sbin/modprobe nbd max_part " .. p_max_part .. " nbds " .. p_nbds);
    end,
    unmod = function()
        return os.execute("sudo -n /usr/sbin/modprobe -r nbd");
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
        return os.execute("sudo -n /usr/bin/qemu-nbd -d " .. p_dev .. " 2>/dev/null");
    end,
    kill = function(p_pid)
        return os.execute("sudo -n /usr/bin/kill -9 ", p_pid);
    end,
    used = function(p_dev)
        if p_dev ~= nil and os.execute("sudo -n /usr/bin/lsof -t " .. p_dev .. " 2>/dev/null") ~= nil then
            local fd;
            fd = io.popen("/usr/bin/lsof -t " .. p_dev .. " 2>/dev/null");
            return (#fd:read("a*") > 0);
        else
            return false
        end
    end,
    usewho = function(p_dev)
        local fd;
        if os.execute("sudo -n /usr/bin/lsof -t " .. p_dev ..
                          " | /usr/bin/grep \"$(/usr/bin/pgrep qemu-nbd)\"  2>/dev/null") ~= nil then
            fd =
                io.popen("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep qemu-nbd)\"  2>/dev/null"); ---
            if fd ~= nil and (#fd:read("a*") > 0) then
                return 1
            end
        else
            return false;
        end ---
        if os.execute("sudo -n /usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep tgtd)\" 2>/dev/null") ~=
            nil then
            fd = io.popen("/usr/bin/lsof -t " .. p_dev .. " | /usr/bin/grep \"$(/usr/bin/pgrep tgtd)\" 2>/dev/null"); ---
            if fd ~= nil and (#fd:read("a*") > 0) then
                return 2
            end
        else
            return false;
        end
    end
};
nsboot.cmd.img = {
    new = function(p_path, p_size)
        return os.execute(
            "/usr/bin/qemu-img -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on encryption=off " ..
                p_path .. " " .. p_size);
    end,
    child = function(p_parrent, p_child)
        return os.execute("sudo -n /usr/bin/qemu-img create -f qcow2 -b " .. p_parrent .. " " .. p_child ..
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
        if os.execute("sudo -n /usr/bin/lsof " .. p_image .. " 2>/dev/null") ~= nil then
            local fd;
            fd = io.popen("/usr/bin/lsof -t " .. p_image .. " 2>/dev/null");
            return (#fd:read("a*") > 0);
        else
            return false;
        end
    end
};

nsboot.cmd.zfs = {
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
        return os.execute("sudo -n /usr/sbin/zfs snap " .. p_data .. " 2>/dev/null");
    end,
    unsnap = function(p_data)
        return os.execute("sudo -n /usr/sbin/zfs destroy -f " .. p_data .. " 2>/dev/null");
    end,
    mount = function(p_data, p_point)
        return os.execute("sudo -n /usr/bin/mount -t zfs " .. p_data .. " " .. p_point .. " 2>>/var/log/messages");
    end,
    unmount = function(p_point)
        return os.execute("sudo -n /usr/bin/umount -f " .. p_point .. " 2>/dev/null");
    end
}
nsboot.cmd.power = {

    on = function(p_iface, p_mac)
        return os.execute("sudo -n /usr/sbin/etherwake -i " .. p_iface .. " " .. p_mac);
    end
}

--[[===========================================================================================================================================================================================]]
--[[ TARGET COMMANDS sets opt1,opt2,opt3  ]]
--[[===========================================================================================================================================================================================]]
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
-- nsboot.inc.lsof = function(p_patern)
--     if os.execute("sudo -n /usr/bin/lsof " .. p_patern .. " 2>/dev/null") ~= nil then
--         local fd;
--         fd = io.popen("/usr/bin/lsof " .. p_patern .. " 2>/dev/null");
--         return (#fd:read("a*") > 0);
--     else
--         return false;
--     end

-- end;
nsboot.inc.lsof = function(p_patern)
    local fd;
    fd = io.popen("sudo -n /usr/bin/lsof " .. p_patern .. " 2>/dev/null");
    return (#fd:read("a*") > 0);
end

-- nsboot.inc.lsof = function(args)
--     local handle = io.popen("sudo -n /usr/bin/lsof " .. args)
--     local result = handle:read("*a")
--     handle:close()
--     return result and #result > 0 and result or nil
-- end
nsboot.inc.lsofkill = function(p_path)
    nsboot.inc.debug("TUT 0")
    if os.execute("sudo -n /usr/bin/lsof -t " .. p_path .. " 2>/dev/null") ~= nil then
        local fd;
        fd = io.popen("sudo -n /usr/bin/kill -9 $(/usr/bin/lsof -t " .. p_path .. ") 2>/dev/null");
        return (#fd:read("a*") > 0);
    else
        return false;
    end

end;
nsboot.inc.search_nbd = function()
    for i_index = 1, nsboot.cfg.server.nbd_nbds, 1 do
        nsboot.inc.debug("TUT 2")
        if os.execute("sudo -n /usr/bin/lsof /dev/nbd" .. i_index .. " 2>/dev/null | sudo -n /usr/bin/wc -l") ~= nil then
            local fd;
            fd = io.popen("sudo -n /usr/bin/lsof /dev/nbd" .. i_index .. " 2>/dev/null | sudo -n /usr/bin/wc -l");
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
        if os.execute("sudo -n /usr/bin/lsof -t " .. t_path .. " 2>/dev/null") ~= nil then

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
    local cmd = "/usr/bin/systemctl " .. p_cmd .. " " .. p_name
    return os.execute("sudo -n /usr/bin/systemctl " .. p_cmd .. " " .. p_name)

end
nsboot.inc.monit = function()

    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.dhcp.port) then
        nsboot.inc.systemctl("isc-dhcp-server", "start");
        nsboot.inc.systemctl("isc-dhcp-server", "restart");
    end
    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.tftp.port) then
        ngx.print("TFTP PORT: " .. nsboot.cfg.tftp.port)
        nsboot.inc.systemctl("tftpd-hpa", "start");
        nsboot.inc.systemctl("tftpd-hpa", "restart");
    end
    if not nsboot.inc.lsof("-t -i:" .. nsboot.cfg.iscsi.port) then
        nsboot.inc.systemctl("tgt", "start");
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
    os.execute("sudo -n /usr/sbin/arp -a " .. p_ip .. " | /usr/bin/awk '{ print $4 }' > " .. f_tmp)
    f_mac = io.open(f_tmp, "r")
    f_data = f_mac:read("*a")
    f_mac:close()
    os.remove(f_tmp)
    return f_data
end
--[[ TARGET COMMANDS sets opt1,opt2,opt3  ]]
--[[===========================================================================================================================================================================================]]

function nsboot:SaveToFile(fpath, t_data)
    if nsboot.inc.checkconf() then
        local json, result, file = require("cjson");
        file = io.open(fpath, "w");
        if file then
            result = json.encode(t_data)
            file:write(result);
            file:close()
            return true
        else
            return false, "Could not open file for writing: " .. fpath
        end
    else
        return false
    end
end
function nsboot:LoadFromFile(fpath)
    local l_data, l_result, file = {};
    file = io.open(fpath, "r");
    if file then
        l_result = file:read("*a");
        file:close()
        l_data = nsboot.lib.json.decode(l_result)
        return l_data
    else
        return nil, "Could not open file for reading: " .. fpath
    end
end
function nsboot:ExportDHCP()
    if nsboot.inc.checkconf() then
        -- if isDir(nsboot.cfg.dhcp.workdir) and isFile(nsboot.cfg.dhcp.workdir.."/dhcpd.conf") then

        local temp_file_path = "/tmp/dhcpd.conf.new"
        local file, err = io.open(temp_file_path, "w")

        if not file then
            ngx.log(ngx.ERR, "Failed to open termporary DHCP config file: " .. (err or "unknown error"))
            return false
        end

        -- os.rename(nsboot.cfg.dhcp.workdir .. "/dhcpd.conf",
        --     nsboot.cfg.dhcp.workdir .. "/dhcpd.conf.backup_" .. os.date("%D%T"):gsub('%W', ''));
        -- local file, err = io.open(nsboot.cfg.dhcp.workdir .. "/dhcpd.conf", "w");

        file:write("## ### THIS FILE AUTOGEENERATION ### #\n");
        file:write("# ### " .. nsboot.cfg.server.vendor .. " " .. nsboot.cfg.server.version .. "______  ### #\n");
        file:write("#[============================================================================================]#\n");
        for i, v in pairs(nsboot.cfg.dhcp.config.global) do
            file:write(i, " ", tostring(v) .. ";\n");
        end
        file:write("#[============================================================================================]#\n");
        i, v = nil, nil
        for i, v in pairs(nsboot.cfg.dhcp.config.opt) do
            if i == 'domain-name' then
                file:write("	option " .. i, " \"", tostring(v) .. "\";\n");
            else
                file:write("	option " .. i, " ", tostring(v) .. ";\n");
            end
        end
        file:write("#[============================================================================================]#\n");
        i, v = nil, nil
        for i, v in ipairs(nsboot.cfg.dhcp.config.sub) do
            file:write("	subnet ", v.sub, " netmask ", v.mask, " {\n");
            local k, val
            for k, val in ipairs(v.ranges) do
                file:write("            range ", val, ";\n");
            end
            k, val = nil, nil;
            file:write("}\n");
        end
        file:write("#[============================================================================================]#\n");
        file:write(nsboot.cfg.dhcp.config.ipxe, "\n");
        file:write("#[============================================================================================]#\n");
        i, v = nil, nil
        for i, v in pairs(nsboot.cfg.wks) do
            if v.name ~= nil then
                if tostring(v.enable) == "1" then
                    file:write("host ", v.name, " {\n");
                    file:write("	hardware ethernet ", v.mac, " ;\n");
                    file:write("	fixed-address ", v.ipv4, ";\n");
                    file:write("	option host-name \"", v.name, "\";\n");
                    file:write("	if substring (option vendor-class-identifier, 15, 5) = \"00000\" {\n");
                    file:write("		filename \"", v.fileboot, ".kpxe\";\n");
                    file:write("	}\n");
                    file:write("	elsif substring (option vendor-class-identifier, 15, 5) = \"00006\" {\n");
                    file:write("		filename \"", v.fileboot, "32.efi\";\n");
                    file:write("	}\n");
                    file:write("	else {\n");
                    file:write("		filename \"", v.fileboot, ".efi\";\n");
                    file:write("	}\n");

                end
                local k, val
                for k, val in ipairs(v.opt) do
                    file:write("option	", val, ";\n");
                end
                file:write("}\n");
            end

            k, val = nil, nil
        end
        file:close();
        i, v = nil, nil
        local backup_cmd = "sudo -n /bin/mv " .. nsboot.cfg.dhcp.workdir .. "/dhcpd.conf " .. nsboot.cfg.dhcp.workdir ..
                               "/dhcpd.conf.backup_" .. os.date("%D%T"):gsub('%W', '')
        os.execute(backup_cmd)

        local move_cmd = "sudo -n /bin/cp " .. temp_file_path .. " " .. nsboot.cfg.dhcp.workdir .. "/dhcpd.conf"
        os.execute(move_cmd)

        -- Clean up and set permissions
        -- os.execute("sudo -n chmod 644 " .. nsboot.cfg.dhcp.workdir .. "/dhcpd.conf")
        -- os.remove(temp_file_path)
        -- end;
    end
end

--[[ TARGET COMMANDS sets opt1,opt2,opt3  ]]
--[[===========================================================================================================================================================================================]]
function nsboot:tgtstart(p_ip)
    nsboot.inc.monit()
    if nsboot.inc.scCheck() and nsboot.inc.checkconf() then
        local l_id = nsboot.inc.GetIDFromIPv4(p_ip);
        if tostring(nsboot.cfg.server.debug) == "1" then
            print(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', ''), nsboot.cfg.wks[l_id].tid);
            print(nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')));
        end
        if not nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')) and
            tostring(nsboot.cfg.wks[l_id].enable) == "1" then
            nsboot.cmd.tgt.new(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', ''),
                nsboot.cfg.wks[l_id].tid);
            nsboot.cmd.tgt.rules(nsboot.cfg.wks[l_id].tid, p_ip);
        end
        if tostring(nsboot.cfg.server.debug) == "1" then
            print("STARTED !");
            print(nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')));
        end
    end
end
function nsboot:tgtstop(p_ip)
    nsboot.inc.monit()
    if nsboot.inc.scCheck() and nsboot.inc.checkconf() then
        local l_id = nsboot.inc.GetIDFromIPv4(p_ip);
        if tostring(nsboot.cfg.server.debug) == "1" then
            print(nsboot.cfg.wks[l_id].tid);
            print(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', ''));
            print(nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')));
        end
        -- if 
        if nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')) then
            nsboot.cmd.tgt.kill(nsboot.cfg.wks[l_id].tid);
        end
        if tostring(nsboot.cfg.server.debug) == "1" then
            print(nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')));
        end
    end
end
--[[===========================================================================================================================================================================================]]
function nsboot:mkChild(p_ip)
    local l_id, l_lockf, p_child, p_parrent = nsboot.inc.GetIDFromIPv4(p_ip)
    local l_vid = nsboot.cfg.wks[l_id].mac:gsub('%W', '')
    if tostring(nsboot.cfg.wks[l_id].enable) == "1" then

        for i, v in pairs(nsboot.cfg.wks[l_id].img) do
            l_lockf = nsboot.cfg.server.lockfile .. i .. l_vid;

            --[[ PROCESS FIND PATH PARRENTS ]] --

            if tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(v.enable) == "1" and v.type == "dyndisk" then
                if tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(nsboot.cfg.wks[l_id].supper) == "1" and
                    tostring(v.enable) == "1" and tostring(v.commit) == "1" then
                    p_parrent = nsboot.cfg.server.imgdir .. "/" .. v.path;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid;
                end
                if tostring(nsboot.cfg.wks[l_id].supper) == "0" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "0" then
                    p_parrent = nsboot.cfg.server.imgdir .. "/" .. nsboot.cfg.zfs.tmpname .. "/" .. l_vid .. "/" ..
                                    v.path;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end --
                if tostring(nsboot.cfg.wks[l_id].supper) == "0" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "1" then
                    p_parrent = nsboot.cfg.server.imgdir .. "/" .. nsboot.cfg.zfs.tmpname .. "/" .. l_vid .. "/" ..
                                    v.path;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end
                if tostring(nsboot.cfg.wks[l_id].supper) == "1" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "0" then
                    p_parrent = nsboot.cfg.server.imgdir .. "/" .. nsboot.cfg.zfs.tmpname .. "/" .. l_vid .. "/" ..
                                    v.path;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end
            elseif tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(v.enable) == "1" and v.type == "dynblock" then
                if tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(nsboot.cfg.wks[l_id].supper) == "1" and
                    tostring(v.enable) == "1" and tostring(v.commit) == "1" then
                    p_parrent = nsboot.cfg.zfs.devpoint .. "/" .. v.path;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid;
                end
                if tostring(nsboot.cfg.wks[l_id].supper) == "0" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "0" then
                    p_parrent = nsboot.cfg.zfs.devpoint .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                                    l_vid;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end --
                if tostring(nsboot.cfg.wks[l_id].supper) == "0" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "1" then
                    p_parrent = nsboot.cfg.zfs.devpoint .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                                    l_vid;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end
                if tostring(nsboot.cfg.wks[l_id].supper) == "1" and tostring(v.enable) == "1" and tostring(v.commit) ==
                    "0" then
                    p_parrent = nsboot.cfg.zfs.devpoint .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                                    l_vid;
                    p_child = nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix .. l_vid
                end
            end

            if tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(v.enable) == "1" and v.type ~= "iso" then
                --[[ PROCESS CREATE CHILD FILE ]] --

                if tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(nsboot.cfg.wks[l_id].supper) == "1" and
                    tostring(v.enable) == "1" and tostring(v.commit) == "1" and not nsboot.inc.isFile(l_lockf) and
                    nsboot.inc.isFile(p_child) then
                    while nsboot.cmd.img.used(p_child) do
                        nsboot.inc.lsofkill(p_child)
                        require("posix.unistd").sleep(0.5);
                    end
                    nsboot.cmd.img.del(p_child);
                    nsboot.cmd.img.child(p_parrent, p_child);
                    local tmpfile = io.open(l_lockf, "w");
                elseif tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(nsboot.cfg.wks[l_id].supper) == "1" and
                    tostring(v.enable) == "1" and tostring(v.commit) == "1" and not nsboot.inc.isFile(l_lockf) and
                    not nsboot.inc.isFile(p_child) then
                    local tmpfile = io.open(l_lockf, "w")
                    nsboot.cmd.img.child(p_parrent, p_child);
                elseif tostring(nsboot.cfg.wks[l_id].enable) == "1" and tostring(nsboot.cfg.wks[l_id].supper) == "1" and
                    tostring(v.enable) == "1" and tostring(v.commit) == "1" and nsboot.inc.isFile(l_lockf) and
                    nsboot.inc.isFile(p_child) then
                    local tmpfile = io.open(l_lockf, "w");
                else
                    if nsboot.inc.isFile(p_child) then
                        while nsboot.cmd.img.used(p_child) do
                            nsboot.inc.lsofkill(p_child)
                            require("posix.unistd").sleep(0.5);
                        end
                        nsboot.cmd.img.del(p_child);
                        if nsboot.inc.isFile(l_lockf) then
                            os.remove(l_lockf)
                        end
                    end
                    if p_parrent ~= nil and p_child ~= nil then
                        while not nsboot.inc.isFile(p_parrent) do
                            require("posix.unistd").sleep(0.5);
                        end
                        nsboot.cmd.img.child(p_parrent, p_child);
                        ngx.say(p_parrent, " ", p_child)
                    end
                end
                ngx.say(p_parrent, " ", i, " ", p_child)
                ngx.say("\n\nnext 1\n\n")
                p_child, p_parrent, l_lockf = nil, nil, nil
            end
        end
    end
    l_id, i, v = nil, nil, nil;
end
function nsboot:rmChild(p_ip)

    local l_id, i, v, img_bpath, img_ppath = nsboot.inc.GetIDFromIPv4(p_ip);
    if nsboot.cfg.wks[l_id].img ~= nil then
        for i, v in pairs(nsboot.cfg.wks[l_id].img) do
            if nsboot.inc.checkconf() and v.path ~= nil and v.type == "dyndisk" and tostring(v.enable) == "1" then
                img_bpath, img_ppath =
                    nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                        nsboot.cfg.wks[l_id].mac:gsub('%W', ''), nsboot.cfg.server.imgdir .. "/" .. v.path;
            elseif nsboot.inc.checkconf() and v.path ~= nil and v.type == "dyndata" and tostring(v.enable) == "1" then
                img_bpath, img_ppath =
                    nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                        nsboot.cfg.wks[l_id].mac:gsub('%W', ''), nsboot.cfg.server.imgdatadir .. "/" .. v.path;
            end
            if img_ppath then
                if nsboot.inc.isFile(img_bpath) then
                    while nsboot.cmd.img.used(img_bpath) do
                        nsboot.inc.lsofkill(img_bpath)
                        require("posix.unistd").sleep(0.5);
                    end
                    nsboot.cmd.img.del(img_bpath);
                end
            end
            img_ppath = nil;
        end
    end
end
function nsboot:checkstatpc(p_ip)
    local fd, result
    fd = io.popen("sudo -n /usr/sbin/tgtadm --lld iscsi --op show --mode target | /usr/bin/grep 'IP Address: " .. p_ip .. "'"); -- /usr/sbin/tgtadm --lld iscsi --op show --mode target | grep --color "IP Address: 192.168.1.4"
    return (#fd:read("a*") > 0);
end

--[[===========================================================================================================================================================================================]]
function nsboot:nbdFree(p_ip)
    local l_id, i, v = nsboot.inc.GetIDFromIPv4(p_ip);

    if nsboot.cfg.wks[l_id].img ~= nil then

        for i, v in pairs(nsboot.cfg.wks[l_id].img) do

            if nsboot.inc.isFile(nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                                     nsboot.cfg.wks[l_id].mac:gsub('%W', '')) and
                nsboot.inc.getdev_nbd(nsboot.inc.getpid_nbd(nsboot.cfg.server.imgbackdir .. "/" .. v.path ..
                                                                nsboot.cfg.server.image_prefix ..
                                                                nsboot.cfg.wks[l_id].mac:gsub('%W', ''))) ~= nil then
                v.nbd = nsboot.inc.getdev_nbd(nsboot.inc.getpid_nbd(
                    nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                        nsboot.cfg.wks[l_id].mac:gsub('%W', '')));
            else
                v.nbd = nil
            end
            if v.nbd ~= nil then
                ngx.say(v.nbd)
                ngx.say(nsboot.cmd.nbd.used(v.nbd))
                --	while nsboot.cmd.nbd.used(v.nbd) do

                nsboot:tgtstop(p_ip);
                nsboot.cmd.nbd.del(v.nbd);
                require("posix.unistd").sleep(0.5);
                --	end;
            end
        end
    end
    l_id, i, v = nil, nil, nil;
end
function nsboot:nbdConnect(p_ip)
    local l_id, i, v = nsboot.inc.GetIDFromIPv4(p_ip);
    if l_id ~= nil and nsboot.cfg.wks[l_id].img ~= nil then
        for i, v in pairs(nsboot.cfg.wks[l_id].img) do
            v.nbd = nsboot.inc.search_nbd();
            while nsboot.cmd.nbd.used(v.nbd) do
                if tostring(nsboot.cfg.server.debug) == "1" then
                    io.write("blocked: ");
                    print(nsboot.cmd.nbd.usewho(v.nbd));
                end
                if nsboot.cmd.nbd.usewho(v.nbd) == 2 then
                    while nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')) do
                        nsboot:tgtstop(p_ip);
                        require("posix.unistd").sleep(1);
                    end
                elseif nsboot.cmd.nbd.usewho(v.nbd) == 1 then
                    nsboot.cmd.nbd.del(v.nbd);
                end
                require("posix.unistd").sleep(0.5);
            end
            while nsboot.cmd.nbd.used(v.nbd) do
                require("posix.unistd").sleep(0.5);
            end
            if not nsboot.cmd.nbd.used(v.nbd) then
                if tostring(nsboot.cfg.server.debug) == "1" then
                    io.write("unblocked: ");
                    print(v.nbd);
                end
                if v.path ~= nil and tostring(v.enable) == "1" then
                    if tostring(v.enable) == "1" and v.type == "dyndisk" or v.type == "dynblock" then
                        nsboot.cmd.nbd.add(v.nbd,
                            nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                                nsboot.cfg.wks[l_id].mac:gsub('%W', ''), v.cache)
                    end
                end
            end
        end
    end
    l_id, i, v = nil, nil, nil;
end
function nsboot:LunAdd(p_ip)
    local l_id, i, v = nsboot.inc.GetIDFromIPv4(p_ip);
    if nsboot.inc.checkconf() then
        while not nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')) do
            nsboot:tgtstart(p_ip)
            require("posix.unistd").sleep(1);
        end
        if nsboot.cmd.tgt.used(nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '')) then

            for i, v in ipairs(nsboot.cfg.wks[l_id].img) do
                if tostring(nsboot.cfg.server.debug) == "1" then
                    print(v.nbd, nsboot.cfg.server.imgbackdir .. "/" .. v.path .. nsboot.cfg.server.image_prefix ..
                        nsboot.cfg.wks[l_id].mac:gsub('%W', ''));
                end
                if tostring(v.enable) == "1" and v.type == "dyndisk" and nsboot.cfg.wks[l_id].tid ~= nil and
                    nsboot.inc.isFile(v.nbd) then
                    if tostring(nsboot.cfg.server.debug) == "1" then
                        print(nsboot.cfg.wks[l_id].tid);
                    end
                    if tostring(nsboot.cfg.server.debug) == "1" then
                        ngx.say("ADD 1:  :  : NUM:", nsboot.cfg.wks[l_id].tid, i, v.nbd);
                    end
                    nsboot.cmd.lun.add(nsboot.cfg.wks[l_id].tid, i, v.nbd)
                end
                if tostring(v.enable) == "1" and v.type == "dynblock" and nsboot.cfg.wks[l_id].tid ~= nil and
                    nsboot.inc.isFile(v.nbd) then
                    if tostring(nsboot.cfg.server.debug) == "1" then
                        ngx.say("ADD 1:  :  : NUM:", nsboot.cfg.wks[l_id].tid, i, v.nbd);
                    end
                    nsboot.cmd.lun.add(nsboot.cfg.wks[l_id].tid, i, v.nbd)
                end
                if tostring(v.enable) == "1" and v.type == "iso" then
                    ngx.say("ADD 3: " .. l_id .. "  :  : NUM:", nsboot.cfg.server.imgisodir .. "/" .. v.path);
                end
                if tostring(v.enable) == "1" and v.type == "iso" and nsboot.cfg.wks[l_id].tid ~= nil and
                    nsboot.inc.isFile(nsboot.cfg.server.imgisodir .. "/" .. v.path) then
                    if tostring(nsboot.cfg.server.debug) == "1" then
                        ngx.say("ADD 1111:  :  : NUM:", nsboot.cfg.server.imgisodir .. "/" .. v.path);
                    end
                    ngx.say("PATH: ", nsboot.cfg.wks[l_id].tid, i,
                        nsboot.cfg.server.imgisodir .. "/" .. v.path .. " -Y cd")
                    nsboot.cmd.lun.add(nsboot.cfg.wks[l_id].tid, i,
                        nsboot.cfg.server.imgisodir .. "/" .. v.path .. " -Y cd")
                end
            end
        end
    end
end
function nsboot:ImgCommit(id)

end
function nsboot:zfsmount(p_ip)
    local l_id, zdest, zpoint = nsboot.inc.GetIDFromIPv4(p_ip)
    if l_id ~= nil then
        zpoint = nsboot.cfg.zfs.mpoint .. "/" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '');
        zdest = nsboot.cfg.zfs.dpoint .. nsboot.cfg.wks[l_id].mac:gsub('%W', '');
    end
    if nsboot.cfg.wks[l_id] ~= nil then
        nsboot:nbdFree(p_ip);
        nsboot.cmd.zfs.unmount(zpoint);
        nsboot.cmd.zfs.unsnap(zdest);
        lfs.rmdir(zpoint);
        while not nsboot.cmd.zfs.mtab(zdest) do
            require("posix.unistd").sleep(1);
            nsboot.cmd.zfs.snap(zdest);
            lfs.mkdir(zpoint);
            nsboot.cmd.zfs.mount(zdest, zpoint);
        end
        for i, v in ipairs(nsboot.cfg.wks[l_id].img) do
            if tostring(v.enable) == "1" and v.type == "dynblock" then
                nsboot.cmd.zfs.unsnap(nsboot.cfg.zfs.snadev .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                                          nsboot.cfg.wks[l_id].mac:gsub('%W', ''));
                nsboot.cmd.zfs.snap(nsboot.cfg.zfs.snadev .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                                        nsboot.cfg.wks[l_id].mac:gsub('%W', ''));
                ngx.say("ZFS: " .. nsboot.cfg.zfs.snadev .. "/" .. v.path .. "@" .. nsboot.cfg.zfs.tmpname .. "_" ..
                            nsboot.cfg.wks[l_id].mac:gsub('%W', ''))
            end
        end
    end
end
function nsboot:zfsdemount(p_ip)
    local l_id, zdest, zpoint = nsboot.inc.GetIDFromIPv4(p_ip)
    if l_id ~= nil then
        zpoint = nsboot.cfg.zfs.mpoint .. "/" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '');
        zdest = nsboot.cfg.zfs.dpoint .. nsboot.cfg.wks[l_id].mac:gsub('%W', '');
    end
    if nsboot.cfg.wks[l_id].img ~= nil then
        nsboot:nbdFree(p_ip);
        nsboot.cmd.zfs.unmount(zpoint);
        nsboot.cmd.zfs.unsnap(zdest);
        lfs.rmdir(zpoint);
    end

end
--[[===========================================================================================================================================================================================]]
nsboot.inc.web = {}
nsboot.inc.web.pcListen = function()
    local k, v, i, l_id, l_supper, l_status
    for k, v in ipairs(nsboot.cfg.wks) do
        if v ~= nil and v.name ~= nil then
            -- if tostring(v.supper) == "1" then l_supper = '<b style="color:tomato;">YES</b>' else l_supper = "NO";
            if tostring(v.supper) == "1" and nsboot:checkstatpc(v.ipv4) then
                ngx.say(
                    "<tr class=\"ContextMenuTr\" style=\"font-weight: 600;color: tomato;  \"><td><svg width=\"2em\" height=\"1em\" viewBox=\"0 0 16 16\" class=\"bi bi-tv-fill\" fill=\"currentColor\" xmlns=\"http://www.w3.org/2000/svg\"><path fill-rule=\"evenod\" d=\"M2.5 13.5A.5.5 0 0 1 3 13h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zM2 2h12s2 0 2 2v6s0 2-2 2H2s-2 0-2-2V4s0-2 2-2z\"/></svg></td><td>",
                    v.tid, "</td><td>", v.name, "</td><td>", v.ipv4, "</td><td>", v.mac,
                    "</td><td>power on</td><td>yes</td><td>", v.fileboot, "</td><td>", v.img[1].path, "</td><td>",
                    v.img[2].path, "</td><td>", v.img[3].path, "</td></tr>");
            elseif tostring(v.supper) == "1" and not nsboot:checkstatpc(v.ipv4) then
                ngx.say(
                    "<tr class=\"ContextMenuTr\" style=\"font-weight: 600;color: #f9c3b9;  \"><td><svg width=\"2em\" height=\"1em\" viewBox=\"0 0 16 16\" class=\"bi bi-tv-fill\" fill=\"currentColor\" xmlns=\"http://www.w3.org/2000/svg\"><path fill-rule=\"evenod\" d=\"M2.5 13.5A.5.5 0 0 1 3 13h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zM2 2h12s2 0 2 2v6s0 2-2 2H2s-2 0-2-2V4s0-2 2-2z\"/></svg></td><td>",
                    v.tid, "</td><td>", v.name, "</td><td>", v.ipv4, "</td><td>", v.mac,
                    "</td><td>power off</td><td>yes</td><td>", v.fileboot, "</td><td>", v.img[1].path, "</td><td>",
                    v.img[2].path, "</td><td>", v.img[3].path, "</h5></td></tr>");
            elseif tostring(v.supper) == "0" and nsboot:checkstatpc(v.ipv4) then
                ngx.say(
                    "<tr class=\"ContextMenuTr\" style=\"font-weight: 600;color: #4e73df; \"><td><svg width=\"2em\" height=\"1em\" viewBox=\"0 0 16 16\" class=\"bi bi-tv-fill\" fill=\"currentColor\" xmlns=\"http://www.w3.org/2000/svg\"><path fill-rule=\"evenod\" d=\"M2.5 13.5A.5.5 0 0 1 3 13h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zM2 2h12s2 0 2 2v6s0 2-2 2H2s-2 0-2-2V4s0-2 2-2z\"/></svg></td><td>",
                    v.tid, "</td><td>", v.name, "</td><td>", v.ipv4, "</td><td>", v.mac,
                    "</td><td>power on</td><td>no</td><td>", v.fileboot, "</td><td>", v.img[1].path, "</td><td>",
                    v.img[2].path, "</td><td>", v.img[3].path, "</td></tr>");
            elseif tostring(v.supper) == "0" and not nsboot:checkstatpc(v.ipv4) then
                ngx.say(
                    "<tr class=\"ContextMenuTr\" style=\"font-weight: 600;color: #868686;  \"><td><svg width=\"2em\" height=\"1em\" viewBox=\"0 0 16 16\" class=\"bi bi-tv-fill\" fill=\"currentColor\" xmlns=\"http://www.w3.org/2000/svg\"><path fill-rule=\"evenod\" d=\"M2.5 13.5A.5.5 0 0 1 3 13h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zM2 2h12s2 0 2 2v6s0 2-2 2H2s-2 0-2-2V4s0-2 2-2z\"/></svg></td><td>",
                    v.tid, "</td><td>", v.name, "</td><td>", v.ipv4, "</td><td>", v.mac,
                    "</td><td>power off</td><td>no</td><td>", v.fileboot, "</td><td>", v.img[1].path, "</td><td>",
                    v.img[2].path, "</td><td>", v.img[3].path, "</h5></td></tr>");
            end

        end
    end

end;
k, v, i, l_id, l_supper, l_status = nil, nil, nil, nil, nil, nil
-- <tr><td>1</td><td>PC001</td><td>Germany</td><td>Alfreds Futterkiste</td><td>Maria Anders</td><td>Germany</td><td>Alfreds Futterkiste</td><td>Maria Anders</td><td>Germany</td></tr>
--[[===========================================================================================================================================================================================]]
-- return nsboot
function nsboot:GetPage()
    nsboot.inc.monit()
    ngargs = ngx.req.read_body();

    if nsboot.inc.checkconf() then
        if ngx.var.arg_getmebootargs == ngx.var.remote_addr and ngx.var.remote_addr ~= "::1" then

            local l_id, l_num, l_key = nsboot.inc.GetIDFromIPv4(ngx.var.remote_addr);
            ngx.say("#!ipxe\n");
            ngx.say("set  initiator-iqn " .. nsboot.cfg.iscsi.iqn .. ":" .. nsboot.cfg.wks[l_id].mac:gsub('%W', '') ..
                        "\n");
            for l_num, l_key in ipairs(nsboot.cfg.wks[l_id].img) do
                if tostring(l_key.boot) == "1" then
                    ngx.say("set root-path iscsi:${next-server}:" .. nsboot.cfg.iscsi.proto .. ":" ..
                                nsboot.cfg.iscsi.port .. ":" .. l_num .. ":" .. nsboot.cfg.iscsi.iqn .. ":" ..
                                nsboot.cfg.wks[l_id].mac:gsub('%W', '') .. "\n");
                end
                if tostring(l_key.boot) == "2" then
                    ngx.say(
                        "set root0 iscsi:${next-server}:" .. nsboot.cfg.iscsi.proto .. ":" .. nsboot.cfg.iscsi.port ..
                            ":" .. l_num .. ":" .. nsboot.cfg.iscsi.iqn .. ":" ..
                            nsboot.cfg.wks[l_id].mac:gsub('%W', '') .. "\n");
                end
                if tostring(l_key.boot) == "3" then
                    ngx.say(
                        "set root1 iscsi:${next-server}:" .. nsboot.cfg.iscsi.proto .. ":" .. nsboot.cfg.iscsi.port ..
                            ":" .. l_num .. ":" .. nsboot.cfg.iscsi.iqn .. ":" ..
                            nsboot.cfg.wks[l_id].mac:gsub('%W', '') .. "\n");
                end
            end
            ngx.say(nsboot.cfg.web.pages.ipxe.body:gsub("([\n])", '\n'));
            ngx.say(nsboot.cfg.web.pages.ipxe.footer:gsub("([\n])", '\n'));
            if tostring(nsboot.cfg.wks[l_id].supper) == "1" then
                nsboot.inc.monit();
                nsboot:tgtstop(ngx.var.remote_addr);
                nsboot:nbdFree(ngx.var.remote_addr);
                nsboot:zfsmount(ngx.var.remote_addr);
                nsboot:mkChild(ngx.var.remote_addr);
                nsboot:nbdConnect(ngx.var.remote_addr);
                nsboot:LunAdd(ngx.var.remote_addr);
            else
                nsboot.inc.monit();
                nsboot:tgtstop(ngx.var.remote_addr);
                nsboot:nbdFree(ngx.var.remote_addr);
                nsboot:zfsmount(ngx.var.remote_addr);
                nsboot:mkChild(ngx.var.remote_addr);
                nsboot:nbdConnect(ngx.var.remote_addr);
                nsboot:LunAdd(ngx.var.remote_addr);
            end
            -- nsboot:nbdFree("192.168.1.4");
            -- nsboot:mkChild("192.168.1.4");
            -- nsboot:nbdConnect("192.168.1.4")
            -- nsboot:LunAdd("192.168.1.4");					
            -- ngx.say("#!ipxe\n:start\necho Boot menu\nmenu Selection\necho \"MY SHELL\"\nshell\n");

        elseif ngx.req.get_body_data() then
            local file, temp, l_v, l_k
            temp = nsboot.lib.json.decode(ngx.req.get_body_data():gsub('&', '","'):gsub('^', '{"post":{"'):gsub('=',
                '":"') .. '"}}').post;
            if nsboot.inc.isFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                     nsboot.cfg.server.config) then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config)
            else
                nsboot.cfg = dofile("/srv/nsboot/cfg/cfg.lua").cfg;
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);
            end
            if temp['id'] ~= nil and temp['supper'] == "true" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] ~= nil then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config);
                if temp['jsondata'] ~= nil then
                    local u_i, u_k
                    for u_i, u_k in ipairs(nsboot.lib.json.decode(nsboot.inc.unescape(temp['jsondata']))) do
                        nsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_k)].commit = "1"

                    end
                    u_i, u_k = nil, nil
                    nsboot.cfg.wks[tonumber(temp['id'])].supper = "1"
                    nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                          nsboot.cfg.server.config, nsboot.cfg);
                end
                ngx.say("OK")
            elseif temp['id'] ~= nil and temp['supper'] == "disableUncommit" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config);
                nsboot.cfg.wks[tonumber(temp['id'])].supper = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[1].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[2].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[3].commit = "0"
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);
                ngx.say("OK")
            elseif temp['id'] ~= nil and temp['supper'] == "disableCommit" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config);
                if temp['id'] ~= nil then
                    local u_i, u_k
                    if nsboot.cfg.wks[tonumber(temp['id'])] ~= nil and nsboot.cfg.wks[tonumber(temp['id'])].supper ==
                        "1" then
                        for u_i, u_k in pairs(nsboot.cfg.wks[tonumber(temp['id'])].img) do
                            if tostring(nsboot.cfg.wks[tonumber(temp['id'])].img[u_i].enable) == "1" and
                                tostring(nsboot.cfg.wks[tonumber(temp['id'])].img[u_i].commit) == "1" and
                                nsboot.cfg.wks[tonumber(temp['id'])].img[u_i].type ~= "iso" then
                                p_child = nsboot.cfg.server.imgbackdir .. "/" ..
                                              nsboot.cfg.wks[tonumber(temp['id'])].img[u_i].path ..
                                              nsboot.cfg.server.image_prefix ..
                                              nsboot.cfg.wks[tonumber(temp['id'])].mac:gsub('%W', '');
                                if nsboot.inc.isFile(p_child) then
                                    if nsboot.cfg.wks[tonumber(temp['id'])].ipv4 ~= nil then
                                        nsboot:tgtstop(nsboot.cfg.wks[tonumber(temp['id'])].ipv4);
                                        nsboot:nbdFree(nsboot.cfg.wks[tonumber(temp['id'])].ipv4);
                                    end
                                    -- while nsboot.cmd.img.used(p_child) do
                                    -- 	require("posix.unistd").sleep(0.5);
                                    -- end;	
                                    nsboot.cmd.img.commit(p_child);
                                    ngx.say("Commited : ", p_child, " ", nsboot.cfg.wks[tonumber(temp['id'])].ipv4);
                                else
                                    ngx.say("False");
                                end

                            end
                        end
                    end
                    --	p_child = nsboot.cfg.server.imgbackdir.."/"..nsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_k)].commitnsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_k)].path..nsboot.cfg.server.image_prefix..nsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_k)].commitnsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_k)].mac:gsub('%W','');
                    -- nsboot:tgtstop(nsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_i)].ipv4);
                    -- nsboot:nbdFree(nsboot.cfg.wks[tonumber(temp['id'])].img[tonumber(u_i)].ipv4);	

                    nsboot.cfg.wks[tonumber(temp['id'])].supper = "0"
                    u_i, u_k = nil, nil
                end
                nsboot.cfg.wks[tonumber(temp['id'])].supper = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[1].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[2].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[3].commit = "0"
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);

                ngx.say("OK")
            elseif temp['id'] ~= nil and temp['supper'] == "disableCommitPoint" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config);
                nsboot.cfg.wks[tonumber(temp['id'])].supper = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[1].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[2].commit = "0"
                nsboot.cfg.wks[tonumber(temp['id'])].img[3].commit = "0"
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);
                ngx.say("OK")
            elseif temp['id'] ~= nil and temp['supper'] == "supperCheck" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] then
                if tostring(nsboot.cfg.wks[tonumber(temp['id'])].supper) == "1" and
                    nsboot:checkstatpc(nsboot.cfg.wks[tonumber(temp['id'])].ipv4) then
                    ngx.say("2");
                elseif tostring(nsboot.cfg.wks[tonumber(temp['id'])].supper) == "1" and
                    not nsboot:checkstatpc(nsboot.cfg.wks[tonumber(temp['id'])].ipv4) then
                    ngx.say("1");
                else
                    ngx.say(tostring(nsboot.cfg.wks[tonumber(temp['id'])].supper));
                end
            elseif temp['id'] ~= nil and temp['supper'] == "DiskList" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] then
                local t_data = {}, t_i
                if nsboot.cfg.wks[tonumber(temp['id'])].img[1].path ~= nil and
                    nsboot.cfg.wks[tonumber(temp['id'])].img[1].path ~= "none" and
                    tostring(nsboot.cfg.wks[tonumber(temp['id'])].img[1].enable) == "1" then
                    t_data['1'] = nsboot.cfg.wks[tonumber(temp['id'])].img[1].path
                end
                if nsboot.cfg.wks[tonumber(temp['id'])].img[2].path ~= nil and
                    nsboot.cfg.wks[tonumber(temp['id'])].img[2].path ~= "none" and
                    tostring(nsboot.cfg.wks[tonumber(temp['id'])].img[2].enable) == "1" then
                    t_data['2'] = nsboot.cfg.wks[tonumber(temp['id'])].img[2].path
                end
                if nsboot.cfg.wks[tonumber(temp['id'])].img[3].path ~= nil and
                    nsboot.cfg.wks[tonumber(temp['id'])].img[3].path ~= "none" and
                    tostring(nsboot.cfg.wks[tonumber(temp['id'])].img[3].enable) == "1" then
                    t_data['3'] = nsboot.cfg.wks[tonumber(temp['id'])].img[3].path
                end
                ngx.say(nsboot.lib.json.encode(t_data));
                t_data = nil
            end
            --[[ COMMAND GET WEB ADMIN ]] --
            if temp['id'] ~= nil and temp['cmd'] == "PowerON" and nsboot.inc.checkconf() and
                nsboot.cfg.wks[tonumber(temp['id'])] ~= nil then
                if tostring(nsboot.cfg.wks[tonumber(temp['id'])].enable) == "1" and
                    nsboot.cfg.wks[tonumber(temp['id'])].mac ~= nil then
                    local l_k, l_v
                    for l_k, l_v in pairs(nsboot.cfg.server.ifaces) do
                        if nsboot.cfg.server.ifaces[l_k] ~= nil then
                            nsboot.cmd.power.on(nsboot.cfg.server.ifaces[l_k], nsboot.cfg.wks[tonumber(temp['id'])].mac)
                            ngx.say(nsboot.cfg.server.ifaces[l_k], nsboot.cfg.wks[tonumber(temp['id'])].mac)
                        end
                    end
                    l_k, l_v = nil, nil
                end
            end
            if temp['id'] == "0" and temp['WKSCmd'] == "GetMy" then
                local l_k, l_v, t_id
                for l_k, l_v in ipairs(nsboot.cfg.wks) do
                    if l_v.empty == "true" then
                        t_id = l_k
                        break
                    elseif l_k == tonumber(l_v.tid) then
                        t_id = l_k + 1
                    end
                end
                local l_dns, l_gw, l_dsearch, l_ip
                if nsboot.cfg.dhcp.config.opt['domain-name-servers'] ~= nil then
                    l_dns = nsboot.cfg.dhcp.config.opt['domain-name-servers']
                elseif nsboot.cfg.server.dns1 ~= nil then
                    l_dns = nsboot.cfg.server.dns1
                else
                    l_dns = "127.0.0.1"
                end
                if nsboot.cfg.dhcp.config.opt['routers'] ~= nil then
                    l_gw = nsboot.cfg.dhcp.config.opt['routers']
                elseif nsboot.cfg.server.gateway ~= nil then
                    l_gw = nsboot.cfg.server.gateway
                else
                    l_gw = "127.0.0.1"
                end
                if nsboot.cfg.dhcp.config.opt['domain-name'] ~= nil then
                    l_dsearch = nsboot.cfg.dhcp.config.opt['domain-name']
                else
                    l_dsearch = "nsboot.local"
                end
                if nsboot.cfg.dhcp.config.sub[1].sub ~= nil then
                    l_ip = nsboot.cfg.dhcp.config.sub[1].sub:gsub("[0-9]$", t_id)
                else
                    l_ip = "192.168.10." .. temp['id']
                end
                l_mac = nsboot.inc.isMacARP(l_ip):gsub('\n', '')
                ngx.say("{\"WKS\":{\"enable\":1,\"group\":\"DEFAULT\",\"gateway\":\"" .. l_gw .. "\",\"dns\":\"" ..
                            l_dns .. "\",\"domainsearch\":\"" .. l_dsearch ..
                            "\",\"supper\":0,\"img\":[{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd" ..
                            (t_id + 2) ..
                            "\",\"type\":\"dyndisk\",\"boot\":0,\"cache\":\"none\"},{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd" ..
                            (t_id + 3) ..
                            "\",\"type\":\"dynblock\",\"boot\":0,\"cache\":\"none\"},{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd0\",\"type\":\"iso\",\"boot\":0,\"cache\":\"none\"}],\"fileboot\":\"ipxe\",\"mac\":\"" ..
                            l_mac .. "\",\"tid\":" .. t_id .. ",\"ipv4\":\"" .. l_ip .. "\",\"opt\":[],\"name\":\"PC00" ..
                            t_id .. "\",\"swp\":0},\"images\":{\"dyndisk\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgdir)) .. ",\"iso\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgisodir)) .. ",\"dynblock\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_devices(nsboot.cfg.zfs.devpoint)) .. "},\"groups\":" ..
                            nsboot.lib.json.encode(nsboot.cfg.groups.wks) .. "}")
                l_k, l_v = nil, nil
                l_dns, l_gw, l_dsearch, l_ip = nil, nil
            end
            if temp['id'] ~= "0" and temp['WKSCmd'] == "GetMy" then
                local t_id, t_temp, l_k, l_v = temp['id'], {}
                ngx.say("{\"WKS\":" .. nsboot.lib.json.encode(nsboot.cfg.wks[tonumber(temp['id'])]) .. "," ..
                            "\"images\":{\"dyndisk\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgdir)) .. ",\"iso\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgisodir)) .. ",\"dynblock\":" ..
                            nsboot.lib.json.encode(nsboot.inc.ls_devices(nsboot.cfg.zfs.devpoint)) .. "},\"groups\":" ..
                            nsboot.lib.json.encode(nsboot.cfg.groups.wks) .. "}")
                l_k, l_v, t_temp = nil, nil
            end
            if temp['id'] ~= nil and temp['WKSCmd'] == "ApplyMy" and temp['jsondata'] then
                local t_id, t_tmp = nsboot.lib.json.decode(nsboot.inc.unescape(temp['jsondata'])).WKS.tid,
                    nsboot.lib.json.decode(nsboot.inc.unescape(temp['jsondata'])).WKS
                if nsboot.cfg.wks ~= nil and nsboot.cfg.wks[t_id] == nil then
                    nsboot.cfg.wks[tonumber(t_id)] = t_tmp
                    nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                          nsboot.cfg.server.config, nsboot.cfg);
                    nsboot:ExportDHCP();
                    ngx.say("SAVE CONFIGURATIONS JSON: ")

                end

                l_k, l_v = nil, nil
            end
            if temp['id'] ~= nil and temp['WKSCmd'] == "DeleteMachine" then

                -- ngx.say(nsboot.cfg.wks[tonumber(temp['id'])].tid)
                local tmpfile = io.open("/tmp/fack", "a")
                -- tmpfile:write(nsboot.lib.json.encode(nsboot.cfg.wks))
                if nsboot.cfg.wks[tonumber(temp['id'])] ~= nil and tostring(nsboot.cfg.wks[tonumber(temp['id'])].tid) ==
                    tostring(temp['id']) then
                    nsboot.cfg.wks[tonumber(temp['id'])] = {}
                    nsboot.cfg.wks[tonumber(temp['id'])].empty = "true"
                else
                    ngx.say("ERROR")
                end --

                tmpfile:write(nsboot.lib.json.encode(nsboot.cfg.wks))
                tmpfile:close()
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);

            end
        elseif ngx.var.arg_testzone == "true" then
            local l_k, l_v, t_id
            t_id = "1"
            ngx.say("<html><body><pre>")

            nsboot.inc.monit();
            nsboot:tgtstop("192.168.1.4");
            nsboot:nbdFree("192.168.1.4");
            nsboot:zfsmount("192.168.1.4");
            nsboot:mkChild("192.168.1.4");
            nsboot:nbdConnect("192.168.1.4");
            nsboot:LunAdd("192.168.1.4");
            ngx.say("GOOD!")
            -- ngx.say(nsboot.inc.search_nbd())
            -- ngx.say(nsboot.inc.getpid_nbd("/srv/writeback/win10cc.qcow2_child_b42e992cdddf"))
            -- ngx.say(nsboot.inc.getpid_nbd("/srv/writeback/lord.qcow2_child_b42e992cdddf"))
            if nsboot.inc.getpid_nbd("/srv/writeback/Win10_2004_Russian_x64.iso_child_b42e992cdddf") ~= nil then
                ngx.say(nsboot.inc.getpid_nbd("/srv/writeback/Win10_2004_Russian_x64.iso_child_b42e992cdddf"))
            end
            -- ngx.say(nsboot.inc.getdev_nbd(nsboot.inc.getpid_nbd("/srv/writeback/win10cc.qcow2_child_b42e992cdddf")))
            --		ngx.say(nsboot.inc.isMacARP("192.168.1.4"))
            -- ngx.say("{\"WKS\"={\"enable\":1,\"group\":\"DEFAULT\",\"gateway\":\"DEFAULT\",\"dns\":\"DEFAULT\",\"domainsearch\":\"DEFAULT\",\"supper\":0,\"img\":[{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd"..(t_id+2).."\",\"type\":\"dyndisk\",\"boot\":0,\"cache\":\"none\"},{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd"..(t_id+3).."\",\"type\":\"dynblock\",\"boot\":0,\"cache\":\"none\"},{\"path\":\"none\",\"commit\":0,\"enable\":1,\"nbd\":\"\\/dev\\/nbd0\",\"type\":\"iso\",\"boot\":0,\"cache\":\"none\"}],\"fileboot\":\"ipxe\",\"mac\":\"\",\"tid\":"..t_id..",\"ipv4\":\"\",\"opt\":[],\"name\":\"PC00"..t_id.."\",\"swp\":0},\"images\":{\"dyndisk\":"..nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgdir))..",\"iso\":"..nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgisodir))..",\"dynblock\":"..nsboot.lib.json.encode(nsboot.inc.ls_devices(nsboot.cfg.zfs.devpoint)).."},\"groups\""..nsboot.lib.json.encode(nsboot.cfg.groups.wks).."}")
            -- --ngx.say(nsboot.lib.json.encode(nsboot.inc.ls_files(nsboot.cfg.server.imgdir)))
            ngx.say("</pre></body></html>")
            l_k, l_v = nil, nil
        elseif ngx.var.arg_status == "true" then
            if nsboot.inc.isFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                     nsboot.cfg.server.config) then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir ..
                                                     "/cfg/" .. nsboot.cfg.server.config)
            else
                nsboot.cfg = dofile("/srv/nsboot/cfg/cfg.lua").cfg;
                nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                      nsboot.cfg.server.config, nsboot.cfg);
            end
            ngx.say(nsboot.cfg.web.pages.html.main);
            nsboot.inc.web.pcListen();
            ngx.say(os.date(), [[</table>
						
				        <div class="dropdown-menu dropdown-menu-sm" id="context-menu">
				          <a class="dropdown-item" data-toggle="modal" data-target="#machineModal" onclick="UpdatemModalLabels(true);" data-id="1" href="#">Add machine</a>
				          <a class="dropdown-item" href="#">Add group</a>
				          <a class="dropdown-item" data-toggle="modal" data-target="#machineModal" onclick="UpdatemModalLabels(false);" href="#">Change machine</a>
				          <a class="dropdown-item" data-toggle="modal" data-target="#machineDeleteModal" href="#">Remove</a>
						  <a class="dropdown-item" id="enableSuperModeBtn" href="#" >Enable supper mode</a>
						  <a class="dropdown-item" data-toggle="modal" data-target="#supperModeDisableModal" id="disableSuperModeBtn" href="#">Disable supper mode</a>
				          <a class="dropdown-item" href="#" onclick=GetCommand('PowerON')>Power on</a>

				        </div>

						<div class="modal fade" id="supperModeDiskListModal">
							<div class="modal-dialog">
							  <div class="modal-content">
							  
							    <!-- Modal Header -->
							    <div class="modal-header">
							      <h4 class="modal-title">Modal Heading</h4>
							      <button type="button" class="close" data-dismiss="modal">&times;</button>
							    </div>
							    
							    <!-- Modal body -->
							    <div class="modal-body">

							    </div>
							    
							    <!-- Modal footer -->
							    <div class="modal-footer">
							      <button type="button" class="btn btn-success" data-dismiss="modal" onclick="SetSupper('true');">OK</button>
							      <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
							    </div>
							    
							  </div>
							</div>
						</div>	




						<div class="modal fade" id="machineDeleteModal">
							<div class="modal-dialog">
							  <div class="modal-content">
							  
							    <!-- Modal Header -->
							    <div class="modal-header">
							      <h4 class="modal-title">Modal Heading</h4>
							      <button type="button" class="close" data-dismiss="modal">&times;</button>
							    </div>
							    
							    <!-- Modal body -->
							    <div class="modal-body">
							    	<p>Delete machine?</p>
							    </div>
							    
							    <!-- Modal footer -->
							    <div class="modal-footer">
							      <button type="button" class="btn btn-success" data-dismiss="modal" onclick="DeleteMachine();">OK</button>
							      <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
							    </div>
							    
							  </div>
							</div>
						</div>	


   

						<div class="modal fade" id="machineModal">
							<div class="modal-dialog">
							  <div class="modal-content">
							  
							    <!-- Modal Header -->
							    <div class="modal-header">
							      <h4 class="modal-title">Modal Heading</h4>
							      <button type="button" class="close" data-dismiss="modal">&times;</button>
							    </div>
							    
							    <!-- Modal body -->
							    <div class="modal-body">

								  <div class="form-group row">
								    <div class="col-sm-6">
								        <label class="form-check-label" for="mEnabled">
								          ENABLE
								        </label>
								    </div>
								    <div class="col-sm-6">
								      <div class="form-check">
								      	<input type="hidden" id="mId">
								        <input class="form-check-input" type="checkbox" name="mEnabled" id="mEnabled">
								      </div>
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mTargetId" class="col-sm-6 col-form-label">TARGET ID</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mTargetId" disabled>
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mHostname" class="col-sm-6 col-form-label">HOSTNAME</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mHostname" placeholder="HOSTNAME">
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mGroup" class="col-sm-6 col-form-label">GROUP</label>
								    <div class="col-sm-6">
										<select id="mGroup" class="form-control">
										  <option>Default select</option>
										</select>
								    </div>
								  </div>


 
								  <br/>
								  <hr/>
								  <br/>


								  <div class="form-group row">
								    <label for="mIpAddress" class="col-sm-6 col-form-label">IP ADDRESS</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mIpAddress" placeholder="IP ADDRESS">
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mMacAddress" class="col-sm-6 col-form-label">MAC ADDRESS</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mMacAddress" placeholder="MAC ADDRESS">
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mGateway" class="col-sm-6 col-form-label">GATEWAY</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mGateway" placeholder="GATEWAY">
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mDnsServers" class="col-sm-6 col-form-label">DNS SERVERS</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mDnsServers" placeholder="DNS SERVERS">
								    </div>
								  </div>

								  <div class="form-group row">
								    <label for="mDomainSearch" class="col-sm-6 col-form-label">DOMAIN SEARCH</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mDomainSearch" placeholder="DOMAIN SEARCH">
								    </div>
								  </div>


								  <br/>
								  <hr/>
								  <br/>

								  <div class="form-group row">
								    <label for="mImgSelect" class="col-sm-6 col-form-label" data-lb1="IMAGE" data-lb2="SELECT"></label>
								    <div class="col-sm-6">
										<select id="mImgSelect" class="form-control">
										  <option value="0">IMG 1</option>
										  <option value="1">IMG 2</option>
										  <option value="2">IMG 3</option>
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mImgType" class="col-sm-6 col-form-label" data-lb1="IMAGE" data-lb2="TYPE"></label>
								    <div class="col-sm-6">
										<select id="mImgType" class="form-control">
										  <option value="dyndisk">dyndisk</option>
										  <option value="dynblock">dynblock</option>
										  <option value="iso">iso</option>
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mImgName" class="col-sm-6 col-form-label" data-lb1="IMAGE" data-lb2="NAME"></label>
								    <div class="col-sm-6">
										<select id="mImgName" class="form-control">
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <div class="col-sm-6">
								        <label class="form-check-label" for="mImgEnable" data-lb1="IMAGE" data-lb2="ENABLE"></label>
								    </div>
								    <div class="col-sm-6">
								      <div class="form-check">
								        <input class="form-check-input" type="checkbox" id="mImgEnable">
								      </div>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mImgCache" class="col-sm-6 col-form-label" data-lb1="IMAGE" data-lb2="CACHE"></label>
								    <div class="col-sm-6">
										<select id="mImgCache" class="form-control">
										  <option value="none">none</option>
										  <option value="unsafe">unsafe</option>
										  <option value="writeback">writeback</option>
										</select>
								    </div>
								  </div>

								  <br/>
								  <hr/>
								  <br/>

								  <div class="form-group row">
								    <label for="mBoot1" class="col-sm-6 col-form-label">SELECT BOOT 1</label>
								    <div class="col-sm-6">
										<select id="mBoot1" class="form-control" data-imgnum="1">
										  <option value="0">none</option>
										  <option value="1">IMG 1</option>
										  <option value="2">IMG 2</option>
										  <option value="3">IMG 3</option>
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mBoot2" class="col-sm-6 col-form-label">SELECT BOOT 2</label>
								    <div class="col-sm-6">
										<select id="mBoot2" class="form-control"  data-imgnum="2">
										  <option value="0">none</option>
										  <option value="1">IMG 1</option>
										  <option value="2">IMG 2</option>
										  <option value="3">IMG 3</option>
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mBoot3" class="col-sm-6 col-form-label">SELECT BOOT 3</label>
								    <div class="col-sm-6">
										<select id="mBoot3" class="form-control" data-imgnum="3">
										  <option value="0">none</option>
										  <option value="1">IMG 1</option>
										  <option value="2">IMG 2</option>
										  <option value="3">IMG 3</option>
										</select>
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mPxeFile" class="col-sm-6 col-form-label">PXE FILE</label>
								    <div class="col-sm-6">
								      <input type="text" class="form-control" id="mPxeFile" placeholder="PXE FILE">
								    </div>
								  </div>
								  <div class="form-group row">
								    <label for="mHwProfile" class="col-sm-6 col-form-label">HARDWARE PROFILE</label>
								    <div class="col-sm-6">
										<select id="mHwProfile" class="form-control">
										</select>
								    </div>
								  </div>

							    </div>
							    
							    <!-- Modal footer -->
							    <div class="modal-footer">
							      <button type="button" class="btn btn-success" data-dismiss="modal" onclick="SaveMachineSettings();">OK</button>
							      <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
							    </div>
							    
							  </div>
							</div>
						</div>	

						<div class="modal spinner fade bd-example-modal-lg" id="spinnerModal" data-backdrop="static" data-keyboard="false" tabindex="-1">
						    <div class="modal-dialog modal-sm">
						        <div class="modal-content" style="width: 48px">
						        <div class="spinner-border text-primary" role="status">
						          <span class="sr-only">Loading...</span>
						         </div>
						        </div>
						    </div>
						</div>

						<div class="modal fade" id="supperModeDisableModal">
							<div class="modal-dialog">
							  <div class="modal-content">
							  
							    <!-- Modal Header -->
							    <div class="modal-header">
							      <h4 class="modal-title">Modal Heading</h4>
							      <button type="button" class="close" data-dismiss="modal">&times;</button>
							    </div>
							    
							    <!-- Modal body -->
							    <div class="modal-body">
							    <form>
							    	update disks?
							    	<div class="custom-control custom-checkbox mb-3">
							    		<input type="checkbox" class="custom-control-input" id="createPointBtn">
							    		<label class="custom-control-label" for="createPointBtn">Create point</label>
							    	</div>
								    <div class="form-group">
								      <label for="pointNameInput">Name:</label>
								      <input type="text" class="form-control" disabled="disabled" id="pointNameInput">
								    </div>
							    </form>
							    </div>
							    
							    <!-- Modal footer -->
							    <div class="modal-footer">
							      <button type="button" class="btn btn-success" onclick="SetSupper('disableCommit');">yes</button>
							      <button type="button" class="btn btn-success" data-dismiss="modal" onclick="SetSupper('disableUncommit');">no</button>
							      <button type="button" class="btn btn-danger" data-dismiss="modal">Cancel</button>
							    </div>
							    
							  </div>
							</div>
						</div>	
								<script>
								]] .. nsboot.cfg.web.bootstrap.js .. [[
								</script>
				        <script>
				        var mResponse = {};

				        $('#createPointBtn').change(function() {
					        if($(this).is(':checked')) {
					        	$('#pointNameInput').removeAttr('disabled');
					        } else {
					        	$('#pointNameInput').attr('disabled', 'disabled');
					        }    
					    });
				        $('tr.ContextMenuTr').dblclick(function(e) {
				        	window.stop();
				        	$('#context-menu').attr('data-id', $(this).children().eq(1).text());
				        	UpdatemModalLabels(false);
				        	$('#machineModal').modal('show');
				        });
				        
					    function UpdatemModalLabels(isAdd){
					    	var mId = $('#context-menu').attr('data-id');
					    	if (isAdd) {
					    		mId = 0;
					    	}
					    	$('#mId').val(mId);
					    	$.ajax({
					    		url:"/",
					    		method:"POST",
					    		data : {
					    			id : mId,
					    			WKSCmd : 'GetMy'
					    		},
					    		success : function(result) {
					    			mResponse = JSON.parse(result);
					    			var gps = '';
					    			$.each(mResponse['groups'], function(k,v){
					    				gps = gps + '<option value="'+v+'">'+v+'</option>';
					    			}); 
					    			$('#mGroup').html(gps);

					    			if (mResponse['WKS']['enable'] == '1') {
					    				$('#mEnabled').prop('checked', true);
					    			} else {
					    				$('#mEnabled').prop('checked', false);
					    			}
					    			$('#mHostname').val(mResponse['WKS']['name']);
					    			$('#mGroup').val(mResponse['WKS']['group']);
					    			$('#mIpAddress').val(mResponse['WKS']['ipv4']);
					    			$('#mMacAddress').val(mResponse['WKS']['mac']);
					    			$('#mTargetId').val(mResponse['WKS']['tid']);
					    			$('#mPxeFile').val(mResponse['WKS']['fileboot']);
					    			$('#mGateway').val(mResponse['WKS']['gateway']);
					    			$('#mDnsServers').val(mResponse['WKS']['dns']);
					    			$('#mDomainSearch').val(mResponse['WKS']['domainsearch']);
					    			$('[data-imgnum').val(0);
					    			$.each(mResponse['WKS']['img'], function(k,v){
					    				$('#mBoot'+v['boot']).val(k + 1);
					    			});
					    			$('#mImgSelect').val('0');
					    			$('#mImgSelect').data('imgindex', parseInt($('#mImgSelect').val()) + 1);
							    	$.each($('[data-lb1]'), function(k,v){
							    		$(v).text($(v).data('lb1') + ' ' + $('#mImgSelect').data('imgindex') + ' ' + $(v).data('lb2'));
							    	});

							    	if (mResponse['WKS']['img'][0]['enable'] == '1') {
							    		$('#mImgEnable').prop('checked', true);
							    	} else {
							    		$('#mImgEnable').prop('checked', false);
							    	}
							    	var diskStr = '<option value="none">none</option>';
							    	var pref = mResponse['WKS']['img'][0]['type'];

							    	if (pref == 'disk' || pref == 'block')
							    		pref = 'dyn'+pref;

							    	$.each(mResponse['images'][pref], function(k,v) {
							    		diskStr = diskStr + '<option value="'+v+'">'+v+'</option>';
							    	});
							    	$('#mImgName').html(diskStr);
							    	$('#mImgType').val(mResponse['WKS']['img'][0]['type']);
							    	$('#mImgName').val(mResponse['WKS']['img'][0]['path']);
							    	$('#mImgCache').val(mResponse['WKS']['img'][0]['cache']);
					    		}
					    	});

					    }

				        function DeleteMachine() {
					    	$.ajax({
					    		url:"/",
					    		method:"POST",
					    		data : {
					    			id : $('#context-menu').attr('data-id'),
					    			WKSCmd : 'DeleteMachine'
					    		},
					    		success : function(result) {
					    			location.reload();
					    		}
					    	});
				        }
					    $('#mImgSelect').on('change', function(e) {
					    	$('#mImgSelect').data('imgindex', parseInt($('#mImgSelect').val()) + 1);
					    	$.each($('[data-lb1]'), function(k,v){
					    		$(v).text($(v).data('lb1') + ' ' +  $('#mImgSelect').data('imgindex') + ' ' + $(v).data('lb2'));
					    	});

					    	if (mResponse['WKS']['img'][$('#mImgSelect').val()]['enable'] == 1) {
					    		$('#mImgEnable').prop('checked', true);
					    	} else {
					    		$('#mImgEnable').prop('checked', false);
					    	}
					    	var diskStr = '<option value="none">none</option>';
					    	$.each(mResponse['images'][mResponse['WKS']['img'][$('#mImgSelect').val()]['type'] ], function(k,v) {
					    		diskStr = diskStr + '<option value="'+v+'">'+v+'</option>';
					    	});
					    	$('#mImgName').html(diskStr);
					    	$('#mImgType').val(mResponse['WKS']['img'][$('#mImgSelect').val()]['type']);
					    	$('#mImgName').val(mResponse['WKS']['img'][$('#mImgSelect').val()]['path']);
					    	$('#mImgCache').val(mResponse['WKS']['img'][$('#mImgSelect').val()]['cache']);
					    });

					    $('#mImgType').on('change', function(e){
					    	mResponse['WKS']['img'][$('#mImgSelect').val()]['type'] = $('#mImgType').val();
					    	var diskStr = '<option value="none">none</option>';
					    	$.each(mResponse['images'][mResponse['WKS']['img'][$('#mImgSelect').val()]['type'] ], function(k,v) {
					    		diskStr = diskStr + '<option value="'+v+'">'+v+'</option>';
					    	});
					    	$('#mImgName').html(diskStr);
					    	$('#mImgName').val('none');
					    	mResponse['WKS']['img'][$('#mImgSelect').val()]['path'] = $('#mImgName').val();
					    });
					    $('#mImgCache').on('change', function(e){
					    	mResponse['WKS']['img'][$('#mImgSelect').val()]['cache'] = $('#mImgCache').val();
					    });
					    $('#mImgName').on('change', function(e){
					    	mResponse['WKS']['img'][$('#mImgSelect').val()]['path'] = $('#mImgName').val();
					    });
					    $('#mImgEnable').change(function(){
					    	if ($('#mImgEnable').is(':checked')) {
					    		mResponse['WKS']['img'][$('#mImgSelect').val()]['enable'] = 1;
					    		console.log(mResponse['WKS']['img'][$('#mImgSelect').val()]['enable']);
					    	} else {
					    		mResponse['WKS']['img'][$('#mImgSelect').val()]['enable'] = 0;
					    		console.log('not checked');
					    	}
					    });


					    $('[data-imgnum]').on('change', function() {
					    	mResponse['WKS']['img'][0]['boot'] = 0;
					    	mResponse['WKS']['img'][1]['boot'] = 0;
					    	mResponse['WKS']['img'][2]['boot'] = 0;

					    	$('[data-imgnum]').each(function(k,v){
					    		if ($(v).val() != 0) {
					    			mResponse['WKS']['img'][(parseInt($(v).val()) - 1)]['boot'] = $(v).data('imgnum');
					    		}
					    	});
					    });

					    function SaveMachineSettings() {
					    	mResponse['WKS']['enable'] = $('#mEnabled').is(':checked') ? 1 : 0;
					    	mResponse['WKS']['tid'] = $('#mTargetId').val();
					    	mResponse['WKS']['name'] = $('#mHostname').val();
					    	mResponse['WKS']['group'] = $('#mGroup').val();

					    	mResponse['WKS']['ipv4'] = $('#mIpAddress').val();
					    	mResponse['WKS']['mac'] = $('#mMacAddress').val();
					    	mResponse['WKS']['gateway'] = $('#mGateway').val();
					    	mResponse['WKS']['dns'] = $('#mDnsServers').val();
					    	mResponse['WKS']['domainsearch'] = $('#mDomainSearch').val();
					    	mResponse['WKS']['fileboot'] = $('#mPxeFile').val();

					    	$.ajax({
					    		url:"/",
					    		method:"POST",
					    		data : {
					    			id : $('#mId').val(),
					    			WKSCmd : "ApplyMy",
					    			jsondata : JSON.stringify(mResponse)
					    		},
					    		success: function(result) {
					    			location.reload();
					    		}
					    	});
					    }


				        /* AJAX Begin POST SEND */


				        $('tr.ContextMenuTr').on('contextmenu', function(e) {
							$('#context-menu').attr('data-id', $(this).children().eq(1).text());
							/*$('#table_refresh').removeAttr('content');*/
							window.stop();
							var top = e.pageY - 10;
							var left = e.pageX - 90;

							$("#context-menu").css({
							display: "block",
							top: top,
							left: left
							}).addClass("show");
				        	$.ajax({
				        		url : "/",
				        		method : "POST",
				        		data : {
				        			id : $('#context-menu').attr('data-id'),
				        			supper : "supperCheck"
				        		},
				        		success : function(result) {
				        			if (result == 1) {
				        				$('#disableSuperModeBtn').removeClass('disabled');
				        				$('#enableSuperModeBtn').addClass('disabled');
				        			} else if (result == 2) {
				        				$('#enableSuperModeBtn').addClass('disabled');
				        				$('#disableSuperModeBtn').addClass('disabled');
				        			} else {
				        				$('#enableSuperModeBtn').removeClass('disabled');
				        				$('#disableSuperModeBtn').addClass('disabled');
				        			}
				        		},
				        		error : function (jqXHR, exception) {
            						console.log(jqXHR);
            					}
				        	});
						  return false; //blocks default Webbrowser right click menu
						});

				        $('#enableSuperModeBtn').on('click', function(e) {
				        	e.preventDefault();
				        	$.ajax({
				        		url : "/",
				        		method : "POST",
				        		data : {
				        			id : $('#context-menu').attr('data-id'),
				        			supper : "DiskList"
				        		},
				        		success : function (result) {
				        			console.log(result);
				        			var data = JSON.parse(result);
				        			var str = "";
				        			$.each(data, function (key, val) {
				        				str = str + '<div class="custom-control custom-checkbox mb-3"><input type="checkbox" class="custom-control-input" value="'+key+'" id="sDisk'+key+'"><label class="custom-control-label" for="sDisk'+key+'">'+val+'</label></div>';
				        			});
				        			$('#supperModeDiskListModal').find('.modal-body').html(str);
				        			$('#supperModeDiskListModal').modal("show");
				        		},
				        		error : function (jqXHR, exception) {
            						console.log(jqXHR);
            					}
				        	});
				        });

				        function SetSupper(SetVal) {
				        	$('#spinnerModal').modal('show');
				        	var jdata = '';
				        	if (SetVal === 'true') {
				        		var disks = [];
				        		$("#supperModeDiskListModal input[type=checkbox]:checked").each(function(){
				        			disks.push($(this).val());
				        		});
				        		jdata = JSON.stringify(disks);
				        	} else if (SetVal === 'disableCommit') {
				        		if ($('#createPointBtn').is(':checked')) {
				        			if ($('#pointNameInput').val().length == 0) {
				        				alert('name must be filled');
				        				return;
				        			}
				        			SetVal = 'disableCommitPoint';
				        			jdata = $('#pointNameInput').val();
				        		}
				        	}
				        	$.ajax({
				        		url : "/",
				        		method : "POST",
				        		data : {
				        			id : $('#context-menu').attr('data-id'),
				        			supper : SetVal,
				        			jsondata : jdata
				        		},
				        		success : function (result) {
				        			$('#supperModeDisableModal').modal("hide");
				        			$('#supperModeDisableModal').find('form')[0].reset();
					        		$('#pointNameInput').attr('disabled', 'disabled');
				        			$('#spinnerModal').modal('hide');
				        			location.reload(); 
				        		},
				        		error : function (jqXHR, exception) {
				        			location.reload(); 
            						console.log(jqXHR);
				        			$('#spinnerModal').modal('hide');
            					}
				        	});
				        }

				        function GetCommand(SetVal) {
				        	var cmdargs = '';
				        	$.ajax({
				        		url : "/",
				        		method : "POST",
				        		data : {
				        			id : $('#context-menu').attr('data-id'),
				        			cmd : SetVal,
				        			cmdargs : cmdargs
				        		},
				        		success : function (result) {
				        			$('#supperModeDisableModal').modal("hide");
				        			$('#supperModeDisableModal').find('form')[0].reset();
					        		$('#pointNameInput').attr('disabled', 'disabled');
				        			location.reload(); 
				        		},
				        		error : function (jqXHR, exception) {
				        			location.reload(); 
            						console.log(jqXHR);
            					}
				        	});
				        }
				        /*AJAX End*/





						function act1() {
								    console.log(this.responseText);




							alert($('#context-menu').attr('data-id'));
						}

						$('body').on("click", function() {
						  $("#context-menu").removeClass("show").hide();
						   /*location.reload(); */ 
						});

						$("#context-menu a").on("click", function() {
						  $(this).parent().removeClass("show").hide();
						  
						});
				        </script>

						]])
            ngx.say("</body></html>");

        else
            if nsboot.inc.isFile(nsboot.cfg.server.config) then
                nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.config)
            else
                nsboot.cfg = dofile("/srv/nsboot/cfg/cfg.lua").cfg;
                nsboot:SaveToFile(nsboot.cfg.server.config, nsboot.cfg);
            end
            ngx.say([[
					<!doctype html>
<html lang="en">
    <head>
        <title>Title</title>
        <!-- Required meta tags -->
        <meta charset="utf-8" />
        <meta
            name="viewport"
            content="width=device-width, initial-scale=1, shrink-to-fit=no"
        />

        <!-- Bootstrap CSS v5.2.1 -->
        <link
            href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css"
            rel="stylesheet"
            integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN"
            crossorigin="anonymous"
        />
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    </head>

    <body>
    
    <nav class="navbar navbar-expand-lg navbar-light bg-light">
    <div class="container-fluid">
    <a class="navbar-brand" href="#">NSBoot</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarText" aria-controls="navbarText" aria-expanded="false" aria-label="Toggle navigation">
    <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarText">
    <ul class="navbar-nav me-auto mb-2 mb-lg-0">
    <li class="nav-item">
    <a class="nav-link active" aria-current="page" href="#">Home</a>
    </li>
    <li class="nav-item">
    <a class="nav-link" href="#Support">Support</a>
    </li>
    <li class="nav-item">
    <a class="nav-link" href="#License">License</a>
    </li>
    
    </ul>
    <button  class="btn btn-link" type="button" aria-controls="navbarNavButton" aria-expanded="false" aria-label="Toggle navigation">
    Logout
    </button>
    </div>
    </div>
    </nav>




    <main class="d-flex flex-wrap h-100 max-vh-100 overflow-x-auto overflow-y-hidden">
        <div class="d-flex flex-column flex-shrink-0 p-3 text-white bg-dark" style="width: 280px;">
            <a href="/" class="d-flex align-items-center mb-3 mb-md-0 me-md-auto text-white text-decoration-none">
                <svg class="bi pe-none me-2" width="40" height="32" aria-hidden="true"><use xlink:href="#bootstrap"></use></svg>
                <span class="fs-4">Sidebar</span>
            </a>
            <hr>
            <ul class="nav flex-column mb-auto" role="tablist" id="myTab">
                <li class="nav-item" role="presentation">
                    <button class="nav-link active" id="dashboard-tab" data-bs-toggle="tab" data-bs-target="#dashboard" type="button" role="tab" aria-controls="dashboard" aria-selected="true">
                        <i class="bi bi-speedometer"></i>
                        Dashboard
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link"  id="computers-tab" data-bs-toggle="tab" data-bs-target="#computers" type="button" role="tab" aria-controls="computers" aria-selected="false">
                        <i class="bi bi-pc-display"></i>
                        Computers
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link"  id="samba-tab" data-bs-toggle="tab" data-bs-target="#samba" type="button" role="tab" aria-controls="samba" aria-selected="false">
                        <i class="bi bi-share"></i>
                        Samba
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link"  id="shell-tab" data-bs-toggle="tab" data-bs-target="#shell" type="button" role="tab" aria-controls="shell" aria-selected="false">
                        <i class="bi bi-terminal"></i>
                        Shell
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link"  id="support-tab" data-bs-toggle="tab" data-bs-target="#support" type="button" role="tab" aria-controls="support" aria-selected="false">
                        <i class="bi bi-life-preserver"></i>
                        Support
                    </button>
                </li>
            </ul>
            <hr>
            <div class="dropdown">
                <a href="#" class="d-flex align-items-center text-white text-decoration-none dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
                <img src="https://github.com/mdo.png" alt="" width="32" height="32" class="rounded-circle me-2">
                <strong>mdo</strong>
                </a>
                <ul class="dropdown-menu dropdown-menu-dark text-small shadow">
                <li><a class="dropdown-item" href="#">New project...</a></li>
                <li><a class="dropdown-item" href="#">Settings</a></li>
                <li><a class="dropdown-item" href="#">Profile</a></li>
                <li><hr class="dropdown-divider"></li>
                <li><a class="dropdown-item" href="#">Sign out</a></li>
                </ul>
            </div>
        </div>
<div class="tabcontent flex-grow-1 p-3 overflow-auto" id="tabcontent">
    

  <div class="tab-pane active" id="dashboard" role="tabpanel" aria-labelledby="dashboard-tab"><h3>Dashboard</h3></div>

    <div class="tab-pane" id="computers" role="tabpanel" aria-labelledby="computers-tab">
        <iframe seamless allow="fullscreen" src="http://]] .. ngx.var.host .. [[:]] .. tostring(nsboot.cfg.server.listen) ..
                        [[?status=true"  class="iframe" id="frame1" name="mainFrame" frameborder="0" scrolling="no" style="width: 100%; height: 100vh;"></iframe>
    </div>
    <div class="tab-pane" id="samba" role="tabpanel" aria-labelledby="samba-tab">Samba Share</div>
    <div class="tab-pane" id="shell" role="tabpanel" aria-labelledby="shell-tab">
        <iframe seamless allow="fullscreen" src="http://]] .. ngx.var.host .. [[:]] .. tostring(nsboot.cfg.server.shell_port) ..
                        [["  class="iframe" id="frame1" name="mainFrame" frameborder="0" scrolling="no" style="width: 100%; height: 100vh;"></iframe>
    </div>
    <div class="tab-pane" id="support" role="tabpanel" aria-labelledby="support-tab">Support</div>

</div>
    </main>
		






<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.5/dist/js/bootstrap.bundle.min.js" integrity="sha384-k6d4wzSIapyDyv1kpU366/PK5hCdSbCRGRCMv+eplOQJWyd1fbcAu9OCUj5zNLiq" crossorigin="anonymous"></script>
<script>

var fFrame = true;

function resizeIframe1(obj) {
	obj.style.height = (parseInt(obj.contentWindow.document.body.clientHeight) + 250) + 'px';
	if (fFrame) {
		fFrame = false;
		obj.contentWindow.location.reload();
	}
}

function resizeIframe2(obj) {
        obj.style.height = (parseInt(document.body.scrollHeight) - 100) + 'px';
}

function openCity(evt, cityName) {
  var i, tabcontent, tablinks;
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }
  tablinks = document.getElementsByClassName("tablinks");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }
  document.getElementById(cityName).style.display = "block";
  evt.currentTarget.className += " active";
}

// Get the element with id="defaultOpen" and click on it
document.getElementById("defaultOpen").click();
</script>


   
</body>
</html> 

			   					]]) -- /*<iframe seamless src="http://]]..ngx.var.host..[[:]]..tostring(nsboot.cfg.server.shell_port)..[["  class="iframe" id="frame" name="mainFrame" scrolling="auto" ></iframe>*/
        end
    end
end
--[[===========================================================================================================================================================================================]]

if nsboot.inc.isFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                         nsboot.cfg.server.config) then
    nsboot.cfg = nsboot:LoadFromFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                                         nsboot.cfg.server.config)
else
    nsboot.cfg = dofile("/srv/nsboot/cfg/cfg.lua").cfg;
    nsboot:SaveToFile(nsboot.cfg.server.workdir .. "/" .. nsboot.cfg.server.distdir .. "/cfg/" ..
                          nsboot.cfg.server.config, nsboot.cfg);
end
nsboot:GetPage()
