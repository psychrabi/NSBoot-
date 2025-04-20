tgt = {
    new = function(opt, p_tid)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --op new --mode target --tid " .. p_tid .. " -T " .. opt);
    end, -- CREATE TARGET
    destroy = function(opt)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --op delete --mode target --tid " .. opt);
    end, -- REMOVE TARGET
    kill = function(opt)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --op delete --force --mode target --tid " .. opt);
    end, -- FORCE REMOVE TARGET
    show = function(opt)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --op show --mode target " .. opt);
    end, -- INFO TARGETS
    rules = function(p_tid, opt)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --mode target --op bind --tid " .. p_tid .. " -I " .. opt);
    end, -- ALLOW CLIENT IP
    unrul = function(p_tid, opt)
        return os.execute("sudo /usr/sbin/tgtadm --lld iscsi --mode target --op unbind --tid " .. p_tid .. " -I " .. opt);
    end,
    used = function(p_tgt)
        local fd; ---
        if os.execute(
            "sudo /usr/sbin/tgtadm --lld iscsi --op show --mode target | /usr/bin/grep --color \"Target [0-9]:\" | /usr/bin/grep " ..
                p_tgt) ~= nil then
            fd = io.popen(
                "sudo /usr/sbin/tgtadm --lld iscsi --op show --mode target | /usr/bin/grep --color \"Target [0-9]:\" | /usr/bin/grep " ..
                    p_tgt); ---
            return (#fd:read("a*") > 0);
        else
            return false;
        end
    end
};

return tgt