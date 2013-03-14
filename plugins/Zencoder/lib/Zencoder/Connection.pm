package Zencoder::Connection;

use strict;
use warnings;

use MT::Util qw( caturl );

# Create the necessary pieces for a connection based on the user's preferences.
# The connection is used to both submit a job to Zencoder and when working with
# a completed job.
sub create_connection {
    my $plugin     = MT->component('zencoder');
    my $pref_conn  = $plugin->get_config_value('connection');
    my $connection = {};

    if ($pref_conn eq 'zencoder-s3') {
        # require Zencoder::Connection::ZencoderS3;
        # It appears we don't actually need anything to complete this. By
        # supplying no `url` int he `outputs`, Zencoder automatically uses its
        # own S3 bucket. The response notification then tells us the URL to use
        # to retrieve it, so there's nothing more to do there, either.
    }
    elsif ($pref_conn eq 'ftp') {
        require Zencoder::Connection::FTP;
        $connection->{base} = Zencoder::Connection::FTP::base();
        $connection->{path} = Zencoder::Connection::FTP::ftp_path();
        $connection->{server_path} = Zencoder::Connection::FTP::server_path();
    }
    else {
        die 'A Zencoder connection was not defined. Visit the plugin Settings '
            . 'and select one.';
    }

    return $connection;
}

# Process a given file from Zencoder's JSON, collecting information about the
# file and moving it to its correct destination to become an asset. Return
# details about the new location of the file, ready to be used with the asset
# object.
sub build_asset_file {
    my ($arg_ref)  = @_;
    my $source_url = $arg_ref->{source_url};
    my $asset      = $arg_ref->{asset};
    my $blog       = $arg_ref->{blog};
    my $fmgr       = $blog->file_mgr;
    my $plugin     = MT->component('zencoder');
    my $pref_conn  = $plugin->get_config_value('connection');

    # Grab the details to build a connection to submit a `url` to Zencoder.
    my $connection = create_connection();

    # In order to create a valid asset cache path, the asset's created_on date
    # needs to be populated. Get the current day and assemble it for the field.
    my ($yr, $mo, $day, $hr, $min, $sec) = (localtime(time))[5,4,3,2,1,0 ];
    $yr  += 1900;
    $mo  += 1;
    $mo  = (length($mo) == 1)  ? '0'.$mo  : $mo;
    $day = (length($day) == 1) ? '0'.$day : $day;
    $hr  = (length($hr) == 1)  ? '0'.$hr  : $hr;
    $min = (length($min) == 1) ? '0'.$min : $min;
    $sec = (length($sec) == 1) ? '0'.$sec : $sec;
    $asset->created_on("$yr$mo$day$hr$min$sec");

    # Destination: the $cache_path and $cache_url are the dynamically-created
    # destinations such as `assets_c/2013/01/file.txt`. This is where the
    # new outputs should live.
    my ( $cache_path, $cache_url );
    $cache_path = $cache_url = $asset->_make_cache_path( undef, 1 );

    my $dest_path = $cache_path;
    # If the destination path returns "%r" in the beginning, the path is
    # relative to the blog site path. Replace "%r" with the blog site path so
    # that the file can be moved to the correct location.
    my $blog_site_path = $blog->site_path;
    $dest_path =~ s/%r/$blog_site_path/;

    # If the destination path returns "%a" in the beginning, the path is
    # relative to the blog's archive site path. Replace "%a" with the blog
    # archive site path so that the file can be moved to the correct location.
    my $archive_site_path = $blog->archive_path;
    $dest_path =~ s/%a/$archive_site_path/;

    my $result = {};
    if ($pref_conn eq 'zencoder-s3') {
        require Zencoder::Connection::ZencoderS3;
        $result = Zencoder::Connection::ZencoderS3::save_file({
            source_url => $source_url,
            dest_path  => $dest_path,
            blog       => $blog,
        });
    }
    elsif ($pref_conn eq 'ftp') {
        require Zencoder::Connection::FTP;
        $result = Zencoder::Connection::FTP::save_file({
            connection => $connection,
            source_url => $source_url,
            dest_path  => $dest_path,
            blog       => $blog,
        });
    }

    return {
        success   => $result->{success},
        file_name => $result->{file_name},
        file_path => File::Spec->catfile( $cache_path, $result->{file_name} ),
        url       => caturl ( $cache_url, $result->{file_name} ),
        file_ext  => $result->{file_ext},
    };
}

1;

__END__
