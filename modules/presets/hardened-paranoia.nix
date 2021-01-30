{
  imports = [
    # Builds on standard hardened profile
    ./hardened.nix
  ];

  ## Settings from madaidan's Linux Hardening Guide
  # See https://madaidans-insecurities.github.io/guides/linux-hardening.html
  # for detailed explanations

  boot.kernel.sysctl = {
    # Prevent boot console kernel log information leaks
    "kernel.printk" = "3 3 3 3";

    # Restrict loading TTY line disciplines to the CAP_SYS_MODULE capability to
    # prevent unprivileged attackers from loading vulnerable line disciplines with
    # the TIOCSETD ioctl
    "dev.tty.ldisc_autoload" = "0";

    # The SysRq key exposes a lot of potentially dangerous debugging functionality
    # to unprivileged users
    "kernel.sysrq" = "4";

    # Protect against time-wait assassination by dropping RST packets for sockets
    # in the time-wait state
    "net.ipv4.tcp_rfc1337" = "1";

    # Disable malicious IPv6 router advertisements
    "net.ipv6.conf.all.accept_ra" = "0";
    "net.ipv6.default.accept_ra" = "0";

    # Disable TCP SACK. SACK is commonly exploited and unnecessary for many
    # circumstances so it should be disabled if you don't require it
    "net.ipv4.tcp_sack" = "0";
    "net.ipv4.tcp_dsack" = "0";

    # Restrict usage of ptrace to only processes with the CAP_SYS_PTRACE
    # capability
    "kernel.yama.ptrace_scope" = "2";

    # Prevent creating files in potentially attacker-controlled environments such
    # as world-writable directories to make data spoofing attacks more difficult
    "fs.protected_fifos" = "2";
    "fs.protected_regular" = "2";

    # Avoid leaking system time with TCP timestamps
    "net.ipv4.tcp_timestamps" = "0";

    # Disable core dumps
    "syskernel.core_pattern" = "|/bin/false";
    "fs.suid_dumpable" = "0";

    # Only swap when absolutely necessary
    "vm.swappiness" = "1";
  };

  boot.kernelParams = [
    # Disable slab merging which significantly increases the difficulty of heap
    # exploitation by preventing overwriting objects from merged caches and by
    # making it harder to influence slab cache layout
    "slab_nomerge"

    # Disable vsyscalls as they are obsolete and have been replaced with vDSO.
    # vsyscalls are also at fixed addresses in memory, making them a potential
    # target for ROP attacks
    "vsyscall=none"

    # Disable debugfs which exposes a lot of sensitive information about the
    # kernel
    "debugfs=off"

    # Sometimes certain kernel exploits will cause what is known as an "oops".
    # This parameter will cause the kernel to panic on such oopses, thereby
    # preventing those exploits
    "oops=panic"

    # Only allow kernel modules that have been signed with a valid key to be
    # loaded, which increases security by making it much harder to load a
    # malicious kernel module
    "module.sig_enforce=1"

    # The kernel lockdown LSM can eliminate many methods that user space code
    # could abuse to escalate to kernel privileges and extract sensitive
    # information. This LSM is necessary to implement a clear security boundary
    # between user space and the kernel
    "lockdown=confidentiality"

    # These parameters prevent information leaks during boot and must be used
    # in combination with the kernel.printk
    "quiet loglevel=0"
  ];
}
