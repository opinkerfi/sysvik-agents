# Test container script
#
#
# Directory containing test files (ex. rpm)
DIR=/tmp/test
#
chcon -Rt svirt_sandbox_file_t  $DIR
podman run -v $DIR:/sysvik -i -t sysvik-test bash
