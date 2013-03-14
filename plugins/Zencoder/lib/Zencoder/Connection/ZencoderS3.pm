package Zencoder::Connection::ZencoderS3;

use strict;
use warnings;

use File::Basename;
use LWP::Simple;

# Move the file from the S3 location to the MT-accessible location.
sub save_file {
    my ($arg_ref)  = @_;
    my $source_url = $arg_ref->{source_url};
    my $dest_path  = $arg_ref->{dest_path};
    my $blog       = $arg_ref->{blog};
    my $fmgr       = $blog->file_mgr;

    my ($filename, undef, $ext) = fileparse($source_url, '\..*?');

    # The extension should not include the query string, which is part of the
    # source url.
    $ext =~ s/^(.*)\?.*$/$1/;

    my $dest = File::Spec->catfile( $dest_path, $filename . $ext);

    # Check if the destination is empty. That is, we don't want to overwrite
    # another file. If the $dest exists we need to come up with a new file name;
    # keep trying to find a new file name until we get something unique.
    my $counter = 0;
    while ( $fmgr->exists($dest) ) {
        # A file already exists at the destination. We want to come up with a
        # unique name for the file so it won't overwrite something else.
        $dest = File::Spec->catfile(
            $dest_path,
            $filename . '-' . ++$counter . $ext
        );
    }

    # Collect the final filename with counter.
    $filename .= '-' . $counter
        if $counter;

    # The $source_url is the S3 location of the transcoded file. Just get it.
    my $http_response = getstore( $source_url, $dest );

    # If $http_response isn't 200 (Success), we need to report the failure.
    if ( $http_response != 200 ) {
        MT->log({
            level   => MT->model('log')->ERROR(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => "Zencoder Notification was unable to save the file "
                . "$source_url to its destination at $dest. Error: "
                . "$http_response.",
        });
        return {
            success => 0,
        };
    }
    
    # The file was successfully copied.
    return {
        success   => 1,
        file_name => $filename . $ext,
        file_ext  => substr($ext, 1), # Strip the leading "."
    };
}

1;

__END__
