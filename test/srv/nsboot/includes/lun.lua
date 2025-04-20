lun = { ---
    add = function(p_tid, p_lun, p_dev)
        return os.execute("/usr/sbin/tgtadm --lld iscsi --op new --mode logicalunit --tid " .. p_tid .. " --lun " ..
                              p_lun .. " -b " .. p_dev);
    end,
    del = function(p_tid, p_lun)
        return os.execute("/usr/sbin/tgtadm --lld iscsi --op delete --mode logicalunit --tid " .. p_tid .. " --lun " ..
                              p_lun);
    end,
    stop = function(p_opt)
        return os.execute("/usr/sbin/tgtadm --offline " .. p_opt);
    end,
    start = function(p_opt)
        return os.execute("/usr/sbin/tgtadm --ready " .. p_opt);
    end
};
return lun