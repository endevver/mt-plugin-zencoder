package Zencoder::CMS;

use strict;
use warnings;

use HTTP::Headers;
use HTTP::Request;
use LWP::UserAgent;
use MT::Util qw( relative_date format_ts dirify caturl );

use Data::Dumper;

sub init_app {
    my $plugin = shift;
    my ($app) = @_;
    return if $app->id eq 'wizard';

    # Check if the Zencoder Email Notification template has already been
    # installed. If not, create it.
    return if MT->model('template')->exist({
        type       => 'email',
        identifier => 'zencoder_notify',
    });

    my $text = <<EMAIL;
Zencoder has finished processing the asset "<mt:AssetLabel>" in the blog <mt:BlogName>. Child assets have been created created and are ready to use wherever you like!

View the parent asset and all of the child assets:
    <mt:CGIPath><mt:AdminScript>?__mode=view&_type=asset&blog_id=<mt:BlogID>&id=<mt:AssetID>
EMAIL

    my $tmpl = MT->model('template')->new();
    $tmpl->type('email');
    $tmpl->identifier('zencoder_notify');
    $tmpl->name('Zencoder Email Notification');
    $tmpl->blog_id('0');
    $tmpl->text( $text );
    $tmpl->save or die $tmpl->errstr;
}

# The listing screen for the Zencoder Output Settings that have been created,
# which also holds the link to create new Output Settings.
sub profile_list {
    my $app     = shift;
    my ($param) = @_;
    my $q       = $app->can('query') ? $app->query : $app->param;
    my $plugin  = MT->component('zencoder');

    # Messaging on the listing screen.
    $param->{profile_deleted} = $q->param('profile_deleted');
    $param->{api_key}         = $plugin->get_config_value('api_key') ? 1 : 0;

    my $blog_id;
    if ( $app->blog ) {
        # Set the $blog_id variable so that it can be used in the terms, below.
        $blog_id = $app->blog->id;
        $param->{blog_id} = $blog_id;
    }

    # Only install the Zencoder default profiles once, on the first visit to the
    # listing screen, so just check if *any* profiles exist.
    if ( !MT->model('zencoder_profile')->exist() ) {
        require Zencoder::Profile;
        Zencoder::Profile::install_default_profiles();
    }

    my $code = sub {
        my ($profile, $row) = @_;
        $row->{id}      = $profile->id;
        $row->{label}   = $profile->label;
        $row->{blog_id} = $profile->blog_id;
        $row->{status}  = $profile->status;

        $row->{format}  = $profile->format;
        $row->{width}   = $profile->width;
        $row->{height}  = $profile->height;
    };

    $app->listing({
        type     => 'zencoder_profile',
        terms    => {
            blog_id => ($blog_id) ? [$blog_id,'0'] : '0',
        },
        args     => {
            sort      => 'label',
            direction => 'ascend',
        },
        listing_screen => 1,
        code     => $code,
        template => $plugin->load_tmpl('profile_list.mtml'),
        params   => $param,
    });
}

# Edit or create a new Output Setting. This appears in a popup dialog, and is
# linked from the listing screen.
sub profile_edit {
    my $app    = shift;
    my $q      = $app->can('query') ? $app->query : $app->param;
    my $plugin = MT->component('zencoder');
    my $param  = {};

    my $profile = MT->model('zencoder_profile')->load( $q->param('id') )
        if $q->param('id');

    if ($profile) {
        # Set the Zencoder-specified fields by just using a prototype. This will
        # make them easy to expand in the future.
        my @keys = qw(
            id label description blog_id status format width height
            max_frame_rate keyframe_interval quality h264_profile h264_level
            h264_keyframe_rate audio_bitrate audio_sample_rate thumb_number
            thumb_interval thumb_times
        );

        foreach my $key ( @keys ) {
            $param->{$key} = $profile->$key;
        }
    }
    # This is a new profile being created; set some default values.
    else {
        $param->{format}         = 'mp4';
        $param->{max_frame_rate} = '30';
        $param->{quality}        = '3';
        $param->{h264_profile}   = 'main';
        $param->{audio_bitrate}  = '128';
    }

    $param->{profile_saved} = $q->param('profile_saved');
    $param->{api_key}       = $plugin->get_config_value('api_key') ? 1 : 0;

    return $plugin->load_tmpl('profile_edit.mtml', $param);
}

# Save the Output Setting being edited/created.
sub profile_save {
    my $app = shift;
    my $q   = $app->can('query') ? $app->query : $app->param;

    my $profile = MT->model('zencoder_profile')->load( $q->param('id') );
    if (!$profile) {
        $profile = MT->model('zencoder_profile')->new();
    }

    # The default non-Zencoder fields.
    $profile->label( $q->param('label') );
    $profile->description( $q->param('description') );
    $profile->status( $q->param('status') );
    $profile->blog_id( $q->param('blog_id') );

    # Set the Zencoder-specified fields by just using a prototype. This will
    # make them easy to expand in the future.
    my @keys = qw(
        format width height status max_frame_rate keyframe_interval quality
        h264_profile h264_level h264_keyframe_rate audio_bitrate
        audio_sample_rate thumb_number thumb_interval thumb_times
    );

    foreach my $key ( @keys ) {
        $profile->$key( $q->param($key) );
    }

    $profile->save or die $profile->errstr;

    # Finally, redirect back to the edit page, and show a message noting that
    # the save was successful.
    $app->redirect(
        $app->mt_uri . '?__mode=zencoder.profile_edit&blog_id=' 
        . $q->param('blog_id') . '&id=' . $profile->id . '&profile_saved=1'
    );
}

# Delete a Zencoder Output Settings Profile
sub profile_delete {
    my ($app) = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;

    my $profile = MT->model('zencoder_profile')->load( $q->param('id') )
        or die 'Could not find a Zencoder Output Settings Profile with the '
            . 'sepcified ID.';

    $profile->remove or die $profile->errstr;

    $app->redirect(
        $app->mt_uri . '?__mode=zencoder.profile_list&blog_id=' 
        . $q->param('blog_id') . '&profile_deleted=1'
    );
}

# When deleting a Zencoder Output Settings Profile from the Listings screen,
# return to the listing screen with any other arguments required (such as
# pagination).
sub profile_itemset_delete {
    my ($app) = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;

    $app->validate_magic or return;

    my @profiles = $q->param('id');
    foreach my $profile_id (@profiles) {
        my $profile = MT->model('zencoder_profile')->load($profile_id)
            or next;

        $profile->remove or die $profile->errstr;
    }

    $app->add_return_arg( profile_deleted => 1 );
    $app->call_return;
}

# The Zencoder Jobs screen simply shows what encoding jobs have been submitted
# to the Zencoder service. It's helpful to know if there's a long queue or if
# something is stuck.
sub job_list {
    my $app     = shift;
    my ($param) = @_;
    my $q       = $app->can('query') ? $app->query : $app->param;
    my $plugin  = MT->component('zencoder');

    # Messaging on the listing screen.
    $param->{api_key}= $plugin->get_config_value('api_key') ? 1 : 0;
    $param->{job_deleted} = $q->param('job_deleted');

    my $blog_id;
    my $blog = MT->model('blog')->load($blog_id);

    if ( $app->blog ) {
        # Set the $blog_id variable so that it can be used in the terms, below.
        $blog_id = $app->blog->id;
        $param->{blog_id} = $blog_id;
    }

    my $code = sub {
        my ($job, $row) = @_;
        $row->{id}            = $job->id;
        $row->{job_id}        = $job->job_id;
        $row->{profile_label} = $job->profile_label;
        $row->{output_id}     = $job->output_id;

        my $asset = MT->model('asset')->load( $job->parent_asset_id );
        if ($asset) {
            $row->{parent_asset_id}      = $asset->id;
            $row->{parent_asset_label}   = $asset->label;
            $row->{parent_asset_blog_id} = $asset->blog_id;
        }

        my $ts = $row->{created_on};
        $row->{created_on_relative} = relative_date($ts, time, $blog );
        $row->{created_on_formatted}
            = format_ts(
                MT::App::CMS::LISTING_DATETIME_FORMAT(),
                $ts, $blog,
                $app->user ? $app->user->preferred_language : undef
            );
    };

    $app->listing({
        type     => 'zencoder_job',
        args     => {
            sort      => 'created_on',
            direction => 'descend',
        },
        listing_screen => 1,
        code     => $code,
        template => $plugin->load_tmpl('job_list.mtml'),
        params   => $param,
    });
}

# When deleting a Zencoder Job from the Listings screen, return to the listing
# screen with any other arguments required (such as pagination).
sub job_itemset_delete {
    my ($app) = @_;
    my $q     = $app->can('query') ? $app->query : $app->param;

    $app->validate_magic or return;

    my @jobs = $q->param('id');
    foreach my $job_id (@jobs) {
        my $job = MT->model('zencoder_job')->load($job_id)
            or next;

        $job->remove or die $job->errstr;
    }

    $app->add_return_arg( job_deleted => 1 );
    $app->call_return;
}


# List Actions and Page Actions both call this function -- to submit the video
# to Zencoder for transcoding.
sub page_action {
    my ($app) = @_;
    $app->validate_magic or return;

    # Many assets may have been selected and submitted. Loop through all of 
    # them and process each one.
    my @asset_ids = $app->param('id');
    foreach my $asset_id (@asset_ids) {
        my $asset = MT->model('asset')->load($asset_id);

        # Skip non-video assets
        next unless $asset->class eq 'video';

        _submit_to_zencoder( $asset );
    }

    $app->call_return;
}

# Decide whether to show the Page Action link based upon what type of asset
# this is. Show the Page Action link only if this asset is a video.
sub page_action_condition {
    my $app   = MT->instance;
    my $q     = $app->can('query') ? $app->query : $app->param;
    my $asset = MT->model('asset')->load( $q->param('id') )
        or return 0;
    return 1 if $asset->class eq 'video';
    return 0;
}

# Submit the selected asset to Zencoder for transcoding. This is where the
# magic happens: we need to load any enabled Output Setting Profiles and create
# a JSON object to submit the request to Zencoder. If the submission was
# successful we can record the job and wait for it to complete.
sub _submit_to_zencoder {
    my ($asset) = @_;
    my $app     = MT->instance;
    my $json    = {};
    my $plugin  = MT->component('zencoder');
    my $blog    = MT->model('blog')->load( $asset->blog_id );
    my $fmgr    = $blog->file_mgr;

    # First, check to see if this asset is in-process with Zencoder already.
    return if MT->model('zencoder_job')->exist({
        parent_asset_id => $asset->id,
    });

    # Prep the FTP credentials to be used for the output URLs.
    my $ftp_server = $plugin->get_config_value('ftp_server');
    my $ftp_user   = $plugin->get_config_value('ftp_user');
    my $ftp_pass   = $plugin->get_config_value('ftp_pass');
    my $ftp_path   = $plugin->get_config_value('ftp_path');
    my $ftp        = '';

    if ( $ftp_server && $ftp_user && $ftp_pass && $ftp_path) {
        # Compose a string to be used for the FTP connection. The $ftp_path is
        # modified for each output, below, to ensure relative uniqueness for
        # each output.
        $ftp = "ftp://$ftp_user:$ftp_pass@" . $ftp_server;
    }
    else {
        die $app->error("Zencoder configuration was not completed: review "
            . "the FTP Connection Configuration fields in Zencoder's plugin "
            . "Settings before resubmitting.");
    }

    $json->{api_key} = $plugin->get_config_value('api_key')
        or die ('The Zencoder API key has not been configured.');

    # The file being submitted for transcoding
    $json->{input} = $asset->url;

    # Grab the output settings profiles and build an array of hashes.
    my @profiles = MT->model('zencoder_profile')->load({
        status => Zencoder::Profile->ENABLE(),
    })
        or die $app->error('No enabled Zencoder Output Setting Profiles '
            . 'could be found. Check that the profiles you want to use are '
            . 'enabled before resubmitting.');

    my @outputs;
    foreach my $profile (@profiles) {
        # $output holds this profile's output setting, which will then be pushed
        # into the @outputs array, which holds all output settings.
        my $output = {};

        # Set the output fields from the profile by just using a prototype.
        # This will make them easy to expand in the future.
        my @keys = qw(
            label format width height max_frame_rate keyframe_interval quality
            h264_profile h264_level h264_keyframe_rate audio_bitrate
            audio_sample_rate
        );

        foreach my $key ( @keys ) {
            $output->{$key} = $profile->$key
                if $profile->$key;
        }

        # Thumbnails require a base_url that tells Zencoder where to place
        # files.
        my $base_url = $ftp . File::Spec->catdir(
            $ftp_path,
            $asset->id,
            dirify( $profile->label ),
        );

        # Thumbnails are an array of hashes within each output hash. Include the
        # type of thumbnail(s) that have been enabled for this profile.
        my @thumbnails;
        push @thumbnails, { 
            number   => $profile->thumb_number,
            label    => 'Number',
            base_url => $base_url,
            format   => 'jpg',
        }
            if $profile->thumb_number;

        push @thumbnails, {
            interval => $profile->thumb_interval,
            label    => 'Interval',
            base_url => $base_url,
            format   => 'jpg',
        }
            if $profile->thumb_interval;

        # Thumbnail times need to be submitted as an array.
        if ( $profile->thumb_times) {
            my @times = split( /\s*,\s*/, $profile->thumb_times );
            push @thumbnails, {
                times    => \@times,
                label    => 'Arbitrary Times',
                base_url => $base_url,
                format   => 'jpg',
            };
        }

        # If any thumbnail options have been selected, add them to the output
        # hash.
        $output->{thumbnails} = \@thumbnails
            if \@thumbnails;

        # The output also needs to have a URL provided for where to save the
        # file. This needs to include the FTP credentials, the absolute path,
        # and a relatively unique filename. $ftp already contains the "base"
        # that the user specified, so to keep things unique use a folder for
        # this output based on the asset and dirified profile label.
        $output->{url} = $ftp . File::Spec->catfile(
            $ftp_path,
            $asset->id,
            dirify( $profile->label ),
            $asset->file_name
        );

        # We want to be notified when this output is complete. Zencoder's
        # notification system will hit notification.cgi with a JSON object
        # detailing the new output.
        my $notification_url = caturl (
            $app->base,
            $app->path,
            $plugin->envelope,
            'notification.cgi'
        );
        push my @notifications, { 
            url    => $notification_url,
            format => 'json',
        };
        $output->{notifications} = \@notifications;

        # Save this output to the array of outputs. (Remember: many output
        # profiles can be handled during a single submission to Zencoder.)
        push @outputs, $output;
    }

    # Finally, save all of these outputs to the JSON object.
    $json->{outputs} = \@outputs;

    # MT->log("JSON, ready to submit: ".Dumper($json));

    # Build the request to be submitted to Zencoder
    my $zencoder_uri = 'https://app.zencoder.com/api/v2/jobs';
    my $req = HTTP::Request->new( 'POST', $zencoder_uri );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( MT::Util::to_json($json) );

    # And actually submit it!
    my $lwp = LWP::UserAgent->new;
    my $response = $lwp->request( $req );

    # Check if the submission was a success. Note that this is only checking if
    # the Zencoder job was accepted and well-formed. That does not mean the job
    # won't fail, just that Zencoder will now start to work on it.
    if (!$response->is_success) {
        use Data::Dumper;
        die $app->error('Error submitting to Zencoder. Response: '
            . Dumper($response));
    }

    # The job was successfully submitted to Zencoder, and we've received a
    # response with some detail about the job. Convert the string response into
    # an object. This response contains the input job ID and the output IDs.
    my $result = JSON::from_json($response->content);

    # Create a new `zencoder_job` object for each output ID, so that MT can
    # track progress.
    foreach my $output ( @{$result->{outputs}} ) {
        my $job = MT->model('zencoder_job')->new();
        $job->blog_id(         $blog->id     );
        $job->job_id(          $result->{id} );
        $job->output_id(       $output->{id} );
        $job->parent_asset_id( $asset->id    );

        # Including the profile label is a little iffy in that we can't
        # correspond the label to a specific Profile object in MT because it's
        # possible the same label is used for multiple Profiles. But still,
        # just displaying the profile label as we receive it could be helpful
        # in the Job Listing just to show what's being worked on. In other
        # words, this isn't precise but is likely helpful.
        $job->profile_label( $output->{label} );

        $job->save or die $job->errstr;
    }

}

# On the Edit Asset screen, we want to note when an asset has been sent to
# Zencoder/is being processed by Zencoder.
sub edit_asset_msg {
    my ($cb, $app, $tmpl) = @_;
    my $q = $app->can('query') ? $app->query : $app->param;

    # If this asset is in the Zencoder Job table, then note that it's being
    # processed.
    if ( MT->model('zencoder_job')->exist({
            parent_asset_id => $q->param('id'),
        })
    ) {
        my $msg = <<END_TMPL;
    <mtapp:statusmsg
        id="zencoder-status"
        class="info">
        <__trans phrase="This asset is currently being processed by Zencoder. You will receive an email when transcoding is complete and the new assets are ready.">
    </mtapp:statusmsg>
END_TMPL

        $$tmpl =~ s{(<MTSetVarBlock name="system_msg">)}{$1$msg}msg;
    }
}

# After uploading a file, the file should be automatically sent to Zencoder for
# processing (if this feature has been enabled in Settings).
sub upload_file_callback {
    my $cb = shift;

    my $params = {};
    while (@_) {
        my $key   = shift;
        my $value = shift;
        $params->{$key} = $value;
    }

    my $plugin = $cb->plugin;
    my $asset  = $params->{asset};

    # If automatic submit is not enabled, quit.
    return if !$plugin->get_config_value('automatic_submit');

    # If this is not a video asset, quit.
    return if $asset->class ne 'video';

    _submit_to_zencoder($asset);
}

1;

__END__
