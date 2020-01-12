#!/usr/bin/env ruby
require 'open3'

# Wait until the given PID had no network activity for `Timeout` seconds, then exit.

pid = ARGV.first
Timeout = 2

stdin, out, err, wait_thread = Open3.popen3("strace -f -e trace=network -s 1 -q -p #{pid}")
while IO.select([err], nil, nil, Timeout)
  begin
    out = err.read_nonblock(1 << 10)
  rescue EOFError
    status = wait_thread.value
    if status.success?
      puts "Monitored process #{pid} exited"
      exit 0
    else
      puts "Strace failed with exit code #{status.to_i}. Last output:\n#{out}"
      # strace often fails with code 256 which looks like success to shells. fail with 1 instead.
      exit 1
    end
  end
end

# If we exit without an explicit kill,
# ptrace can fail on reattachment:  ptrace(PTRACE_SEIZE, $PID): Operation not permitted
# Only relevant for testing.
Process.kill("TERM", wait_thread.pid)
