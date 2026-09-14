# /tflint.ps1
# For executing in repo root
# One shared config, disabling root-only rules for module code
tflint -f compact --recursive --chdir=modules      --config="$(pwd)/.tflint.modules.hcl"
tflint -f compact --recursive --chdir=modulegroup  --config="$(pwd)/.tflint.modules.hcl"

# Environments keep normal config discovery (rule stays enabled)
tflint -f compact --recursive --chdir=environments
