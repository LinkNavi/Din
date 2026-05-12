include {
    std.kernel,
    proc.proc,
}

module Ipc {
    public const uint64 MSG_SIZE = 64;

    // Send a message from src_pid to dst_pid.
    // Blocks the sender if the receiver isn't ready yet.
    // Returns 0 on success, -1 on bad dst.
    public int send(int src_pid, int dst_pid, uint64 msg_ptr) {
        if (dst_pid < 0)          { return -1; }
        if (dst_pid >= Proc.MAX)  { return -1; }

        // Rendezvous: receiver already blocked waiting for us?
        if (Proc.get_state(dst_pid) == cast<uint64>(Proc.BLOCKED)) {
            int dst_src = Proc.ipc_src(dst_pid);
            if (dst_src == -1 || dst_src == src_pid) {
                uint64 dst_buf = Proc.ipc_msgptr(dst_pid);
                memcpy(cast<*void>(dst_buf), cast<*void>(msg_ptr), Ipc.MSG_SIZE);
                Proc.set_ipc(dst_pid, -1, -1, 0);
                Proc.unblock(dst_pid);
                return 0;
            }
        }

        // Block sender until receiver calls recv
        Proc.set_ipc(src_pid, dst_pid, -1, msg_ptr);
        Proc.block(src_pid);
        Proc.schedule();
        return 0;
    }

    // Receive a message into buf_ptr.
    // src_pid = -1 means accept from any sender.
    // Returns the sender pid, or 0 if rescheduled before return.
    public int recv(int dst_pid, int src_pid, uint64 buf_ptr) {
        int i = 0;
        while (i < Proc.MAX) {
            if (i != dst_pid) {
                if (Proc.get_state(i) == cast<uint64>(Proc.BLOCKED)) {
                    int sender_dst = Proc.ipc_dst(i);
                    if (sender_dst == dst_pid) {
                        if (src_pid == -1 || src_pid == i) {
                            uint64 sender_buf = Proc.ipc_msgptr(i);
                            memcpy(cast<*void>(buf_ptr), cast<*void>(sender_buf), Ipc.MSG_SIZE);
                            Proc.set_ipc(i, -1, -1, 0);
                            Proc.unblock(i);
                            return i;
                        }
                    }
                }
            }
            i = i + 1;
        }

        Proc.set_ipc(dst_pid, -1, src_pid, buf_ptr);
        Proc.block(dst_pid);
        Proc.schedule();
        return 0;
    }
}
