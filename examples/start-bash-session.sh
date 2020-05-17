# Start an interactive bash session in the current bash environment.

# BASH_ENVIRONMENT contains definitions of read-only variables like 'BASHOPTS' that
# cause warnings on importing. Suppress these warnings during bash startup.
BASH_ENVIRONMENT=<(declare -p; declare -pf) \
  bash --rcfile <(echo 'source $BASH_ENVIRONMENT 2>/dev/null')
