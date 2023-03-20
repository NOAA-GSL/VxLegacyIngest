#!/bin/csh -f
~moninger/utilities/candf.x <<end > /tmp/$$

$1
end
tail -1 /tmp/$$
rm /tmp/$$

