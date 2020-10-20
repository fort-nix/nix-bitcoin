# Start an interactive bash session in the current bash environment.

USAGE_INFO='
Starting shell...
Run "c COMMAND" to execute a command on the bitcoin node
Run "c" to start a shell session inside the node

Example:
c systemctl status bitcoind
'

# BASH_ENVIRONMENT contains definitions of read-only variables like 'BASHOPTS' that
# cause warnings on evaluation. Suppress these warnings while sourcing.
BASH_ENVIRONMENT=<(declare -p; declare -pf) \
USAGE_INFO="$USAGE_INFO" \
  bash --rcfile <(echo '
    source $BASH_ENVIRONMENT 2>/dev/null
    echo "$USAGE_INFO"
  ')
