# Start an interactive bash session in the current bash environment.
# This is helpful for debugging bash scripts like pkg update scripts,
# by adding `source <path-to>/start-bash-session.sh` at the location to
# be inspected.


# BASH_ENVIRONMENT contains definitions of read-only variables like 'BASHOPTS' that
# cause warnings on evaluation. Suppress these warnings while sourcing.
#
# shellcheck disable=SC2016
BASH_ENVIRONMENT=<(declare -p; declare -pf) \
  bash --rcfile <(echo 'source $BASH_ENVIRONMENT 2>/dev/null')
