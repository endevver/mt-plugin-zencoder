package Zencoder::Notification;

use strict;
use warnings;

use base qw(MT::App);
use MT::Util qw( caturl );
use LWP::Simple;
use JSON;
use File::Basename;
use Zencoder::Connection;

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        'receive_notification'   => \&receive_notification,
    );
    $app->{default_mode} = 'receive_notification';
    $app;
}

# When a job is finished Zencoder will send a notification to `notification.cgi`
# which contains an HTTP POST with a Content-Type header set to
# 'application/json' with information about the input/job.
sub receive_notification {
    my $app    = shift;
    my $q      = $app->can('query') ? $app->query : $app->param;
    my $plugin = MT->component('zencoder');

    # Read the response. It's a string formatted as JSON and simply comes in
    # from the POSTDATA.
    my $data = $q->param('POSTDATA');

    return $app->error('Zencoder Notification failed with an empty submission; '
        . 'no data was provided.'
    )
        if !$data;

    # Convert the string response into an object.
    my $notification = JSON::from_json($data);

    # Dumping the notification JSON to the activity log is a good way to
    # inspect it.
    # use Data::Dumper;
    # MT->log('Zencoder Notification JSON: '.Dumper($notification));

    # The notification JSON object contains details of the job, input, and
    # output. Process the output.
    _process_output({
        output => $notification->{output},
    });

    # Finally, the output in this job has been processed. There should be some
    # sort of notification to authors or display in MT about which items have
    # completed processing... but what?
}

# Process the `output` key to handle the transcoded video that Zencoder created.
sub _process_output {
    my ($arg_ref) = @_;
    my $output    = $arg_ref->{output};

    # The following are keys for the meta that is returned with the output
    # detail. Use this when processing the output, to save these values in case
    # they could be published later.
    my @keys = qw{
        height width audio_bitrate_in_kbps audio_codec audio_sample_rate
        channels duration_in_ms format frame_rate video_bitrate_in_kbps
        video_codec
    };

    # Find the job in the Zencoder Jobs table, which is important primarly
    # because it has the asset parent ID necessary to make the parent-child
    # association and needed metadata.
    my $job = MT->model('zencoder_job')->load({
        output_id => $output->{id},
    });

    # The job *should* be found, unless the database was manually changed...
    if (!$job) {
        return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => 'A Zencoder job output ID of ' . $output->{id}
                . ' could not be found.',
        });
    }

    # Look for any error information in this output before proceeding too far.
    # If the upload failed we want to report it and just give up processing
    # this output.
    if ($output->{primary_upload_error_message}) {
        $job->message(
            $output->{primary_upload_error_message} . ' '
            . $output->{primary_upload_error_link}
        );
        $job->save or die $job->errstr;
        return 0;
    }

    my $blog = MT->model('blog')->load( $job->blog_id )
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't load the specified "
                . "blog (ID " . $job->blog_id . ") to process the output "
                . "from job " . $job->id . " with output ID "
                . $job->output_id . ".",
        });

    # The new output has already been saved onto the server. Turn it into
    # an asset in MT. Use the parent asset to set a parent-child
    # relationship, and to set the metadata of the new asset.
    my $parent_asset = MT->model('asset')->load( $job->parent_asset_id )
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            blog    => $blog->id,
            class   => 'zencoder',
            message => "Zencoder Notification couldn't load the specified "
                . "parent asset (ID " . $job->parent_asset_id . ") to "
                . "process the output from job " . $job->id
                . " with output ID " . $job->output_id . ".",
        });

    # The new output should be based on the parent asset, and just needs
    # some details updated.
    my $asset = $parent_asset->clone({
        except => {           # Don't clone certain existing values
            id          => 1, # ...so the ID will be new/unique
            created_by  => 1, # ...so the creator will be "System"
            created_on  => 1, # ...so the created time will be "now"
            modified_by => 1,
            modified_on => 1,
        },
    });

    # Create the parent-child relationsip to tie the new output asset to
    # the parent.
    $asset->parent( $parent_asset->id );

    # Move the asset from the FTP'd location to the final asset location.
    my $file = Zencoder::Connection::build_asset_file({
        source_url => $output->{url},
        asset      => $asset,
        blog       => $blog,
    });
    # If the file wasn't moved to the correct location, just give up working
    # with this thumbnail. If this failed, it's already been noted in the
    # Activity Log.
    return if !$file->{success};

    $asset->file_path( $file->{file_path} );
    $asset->url(       $file->{url}       );
    $asset->file_name( $file->{file_name} );
    $asset->file_ext(  $file->{file_ext}  );

    # The asset label of the parent asset is fine to use, but we want to
    # differentiate it a little. By appending the Output Setting Profile
    # label we can help the author better know what to use.
    my $label_addition = $output->{label}
        ? ' [' . $output->{label} . ']'
        : ' [' . $output->{width} . ' x ' . $output->{height} . ']';
    $asset->label( $asset->label . $label_addition );

    # Process all of the metadata that is available in the output object.
    foreach my $key (@keys) {
        $asset->$key( $output->{$key} )
            if $output->{$key};
    }

    # Try to save the new asset, and note it in the Activity Log.
    if ($asset->save) {
        MT->log({
            level   => MT->model('log')->INFO(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => 'Zencoder Notification created a new video asset, '
                . $asset->file_name . '.',
        });
    }
    # Asset save failed!
    else {
        return MT->log({
            level   => MT->model('log')->ERROR(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => 'Zencoder Notification could not save a new video '
                . 'asset from the Zencoder job output ID ' . $output->{id} 
                . ' with the URL ' . $output->{url} . '.',
        });
    }

    # Look for any thumbnails that might have been created, also. Go
    # through each element in the `thumbnails` array. A different element
    # is used for each type of thumbnail generated ("number of thumbnails,"
    # "time interval," and "arbitrary times" on the Edit Profile page.)
    my $thumbs = $output->{thumbnails};
    foreach my $thumb (@$thumbs) {
        # An array of images exists for each type of thumbnail.
        my $images = $thumb->{images};
        foreach my $image (@$images) {
            _process_thumbnail({
                image        => $image,
                parent_asset => $asset,
                blog         => $blog,
            });
        }
    }

    # Send an email notification.
    _email_author({
        asset => $parent_asset,
        job   => $job,
    });

    # Finally, the output has been processed, so we can delete the job from
    # the log.
    $job->remove or return MT->log({
        level     => MT->model('log')->ERROR(),
        blog_id   => $job->blog_id,
        message   => 'A Zencoder job with output ID ' . $output->{id} 
            . 'could not be deleted.',
    });
}

# Process a given a thumbnail from the JSON contents and turn it into an asset.
# This is part of the `output` key.
sub _process_thumbnail {
    my ($arg_ref) = @_;
    my $image     = $arg_ref->{image};
    my $parent    = $arg_ref->{parent_asset};
    my $blog      = $arg_ref->{blog};

    my $asset = MT->model('asset.image')->new();
    $asset->blog_id( $parent->blog_id              );
    $asset->parent(  $parent->id                   );
    $asset->label(   $parent->label . ' Thumbnail' );

    # Move the asset from the FTP'd location to the final asset location.
    my $file = Zencoder::Connection::build_asset_file({
        source_url => $image->{url},
        asset      => $asset,
        blog       => $blog,
    });
    # If the file wasn't moved to the correct location, just give up working
    # with this thumbnail. If this failed, it's already been noted in the
    # Activity Log.
    return if !$file->{success};

    $asset->file_path( $file->{file_path} );
    $asset->url(       $file->{url}       );
    $asset->file_name( $file->{file_name} );
    $asset->file_ext(  $file->{file_ext}  );

    # Set the image dimensions based on the `dimensions` key's value
    # which is formatted "1280x720," for example.
    my @dimensions = split( 'x', $image->{dimensions} );
    $asset->image_width(  $dimensions[0] );
    $asset->image_height( $dimensions[1] );

    # Try to save the new asset, and note it in the Activity Log.
    if ($asset->save) {
        MT->log({
            level   => MT->model('log')->INFO(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => 'Zencoder Notification created a new image asset, '
                . $asset->file_name . '.',
        });
    }
    # Asset save failed!
    else {
        return MT->log({
            level   => MT->model('log')->ERROR(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => 'Zencoder Notification could not save a new image '
                . 'asset with the source URL ' . $image->{url} . '.',
        });
    }
}

# Email the author to notify them when new assets are ready to use.
sub _email_author {
    my ($arg_ref) = @_;
    my $asset     = $arg_ref->{asset};
    my $job       = $arg_ref->{job};
    my $app       = MT->instance;
    my $plugin    = MT->component('zencoder');

    # Only proceed if the Email Author checkbox was enabled.
    return if !$plugin->get_config_value('email_author');

    # If multiple Output Setting Profiles are enabled, that means we can expect
    # multiple notifications from Zencoder about each trasncoded file. We want
    # to notify the user only once about success for a given parent asset, so
    # do this by only sending the notification when there is a single row 
    # remaining for this parent asset.
    my $count = MT->model('zencoder_job')->count({
        parent_asset_id => $asset->id,
    });
    return if $count > 1;

    my $blog = MT->model('blog')->load($job->blog_id)
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't load the specified "
                . "blog (ID " . $job->blog_id . ") to send a notification "
                . "email",
        });

    my $author = MT->model('author')->load($job->created_by)
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't load the specified "
                . "author (ID " . $job->created_by . ") to send a notification "
                . "email",
        });

    use MT::Mail;
    my %head = (
        To      => $author->email,
        Subject => '[' . $blog->name . '] Zencoder created a new asset.',
    );

    # Load the Zencoder Email Notification template and use that for the email
    # message body.
    my $tmpl = MT->model('template')->load({
        type       => 'email',
        identifier => 'zencoder_notify',
    })
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't load the Zencoder Email "
                . "Notification template to send a notification email",
        });

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->{__stash}{asset} = $asset;

    my $body = $tmpl->build($ctx)
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't send a notification "
                . "email: " . $tmpl->errstr,
        });

    MT::Mail->send(\%head, $body)
        or return MT->log({
            level   => MT->model('log')->ERROR(),
            class   => 'zencoder',
            message => "Zencoder Notification couldn't send a notification "
                . "email: " . MT::Mail->errstr,
        });
}

1;

__END__

Examples below are from Zencoder's documentation.
https://app.zencoder.com/docs/guides/getting-started/notifications

It appears the only difference is showing that the key may be `output` or
`outputs` depending upon the number of results returned.

Job Notification Example

    {
    "outputs":[
      {
        "height":120,
        "audio_sample_rate":8000,
        "frame_rate":8.0,
        "channels":"1",
        "duration_in_ms":1920,
        "video_bitrate_in_kbps":70,
        "video_codec":"h264",
        "format":"mpeg4",
        "audio_codec":"aac",
        "label":null,
        "file_size_in_bytes":17938,
        "width":160,
        "audio_bitrate_in_kbps":9,
        "id":235314,
        "total_bitrate_in_kbps":79,
        "state":"finished",
        "url":"ftp://example.com/file.mp4",
        "md5_checksum":"7f106918e02a69466afa0ee014172496",
        "thumbnails": [
          {
            "label":"poster",
            "images":
            [
              {
                "url": "ftp://example.com/images/123.png",
                "format": "PNG",
                "file_size_bytes": 1273573,
                "dimensions": "1280x720"
              }
            ]
          }
        ]
      },
      {
        "height":120,
        "audio_sample_rate":8000,
        "frame_rate":8.0,
        "channels":"1",
        "duration_in_ms":1920,
        "video_bitrate_in_kbps":70,
        "video_codec":"h264",
        "format":"mpeg4",
        "audio_codec":"aac",
        "label":null,
        "file_size_in_bytes":17938,
        "width":160,
        "audio_bitrate_in_kbps":9,
        "id":235314,
        "total_bitrate_in_kbps":79,
        "state":"finished",
        "url":"ftp://example.com/file.mp4",
        "md5_checksum":"7f106918e02a69466afa0ee014172496",
        "thumbnails": [
          {
            "label":"poster",
            "images":
            [
              {
                "url": "ftp://example.com/images/123.png",
                "format": "PNG",
                "file_size_bytes": 1273573,
                "dimensions": "1280x720"
              }
            ]
          }
        ]
      }
    ],
    "job":{
        "created_at":"2011-09-27T04:20:10Z",
        "pass_through":null,
        "updated_at":"2011-09-27T04:21:18Z",
        "submitted_at":"2011-09-27T04:20:10Z",
        "id":172151,
        "state":"finished"
      },
    "input":{
        "height":120,
        "audio_sample_rate":8000,
        "frame_rate":8.0,
        "channels":"1",
        "duration_in_ms":1552,
        "video_bitrate_in_kbps":32,
        "video_codec":"mpeg4",
        "format":"mpeg4",
        "audio_codec":"aac",
        "file_size_in_bytes":13960,
        "width":160,
        "audio_bitrate_in_kbps":9,
        "id":172149,
        "state":"finished",
        "total_bitrate_in_kbps":41,
        "md5_checksum":"7f106918e02a69466afa0ee014174143"
      }
    }

Output Notification Example

    {
    "output":{
        "height":120,
        "audio_sample_rate":8000,
        "frame_rate":8.0,
        "channels":"1",
        "duration_in_ms":1920,
        "video_bitrate_in_kbps":70,
        "video_codec":"h264",
        "format":"mpeg4",
        "audio_codec":"aac",
        "label":null,
        "file_size_in_bytes":17938,
        "width":160,
        "audio_bitrate_in_kbps":9,
        "id":235314,
        "total_bitrate_in_kbps":79,
        "state":"finished",
        "url":"ftp://example.com/file.mp4",
        "md5_checksum":"7f106918e02a69466afa0ee014172496"
        "thumbnails":
          [
            {
              "label":"poster",
              "images":
              [
                {
                  "url": "ftp://example.com/images/123.png",
                  "format": "PNG",
                  "file_size_bytes": 1273573,
                  "dimensions": "1280x720"
                }
              ]
            }
          ]
      },
    "job":{
        "created_at":"2011-09-27T04:20:10Z",
        "pass_through":null,
        "updated_at":"2011-09-27T04:21:18Z",
        "submitted_at":"2011-09-27T04:20:10Z",
        "id":172151,
        "state":"finished"
      },
    "input":{
        "height":120,
        "audio_sample_rate":8000,
        "frame_rate":8.0,
        "channels":"1",
        "duration_in_ms":1552,
        "video_bitrate_in_kbps":32,
        "video_codec":"mpeg4",
        "format":"mpeg4",
        "audio_codec":"aac",
        "file_size_in_bytes":13960,
        "width":160,
        "audio_bitrate_in_kbps":9,
        "id":172149,
        "state":"finished",
        "total_bitrate_in_kbps":41,
        "md5_checksum":"7f106918e02a69466afa0ee014174143"
      }
    }

