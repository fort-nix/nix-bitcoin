# Wait until $condition is true, retrying every $intervalMs milliseconds.
# Print a '.' character every second as a progress indicator.
waitUntil() {
    condition=$1
    intervalMs=$2

    lastDotTime=$(getTimeMs)
    while ! { t0=$(getTimeMs); eval "$condition"; }; do
        now=$(getTimeMs)
        if ((now - lastDotTime >= 1000)); then
            printf .
            lastDotTime=$now
        fi
        toSleep=$((t0 + intervalMs - now))
        if ((toSleep > 0)); then
            sleep $((toSleep / 1000)).$((toSleep % 1000));
        fi
    done
}

getTimeMs() { date +%s%3N; }
