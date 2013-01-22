#!/usr/bin/perl -w

# This endpoint is used by Zencoder to supply a JSON object with information
# about the completed output job.

use strict;
use lib "lib", ($ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : "../../lib");
use MT::Bootstrap App => 'Zencoder::Notification';

__END__
