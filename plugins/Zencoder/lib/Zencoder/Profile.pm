package Zencoder::Profile;

use strict;
use warnings;

use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
        id                 => 'integer not null auto_increment',
        blog_id            => 'integer',
        status             => 'integer not null',
        basename           => 'string(255)',
        label              => 'string(255) not null',
        description        => 'text',
        # The following are all the standard Zencoder output key names.
        format             => 'string(25)',
        width              => 'string(25)',
        height             => 'string(25)',
        max_frame_rate     => 'integer',
        keyframe_interval  => 'integer',
        quality            => 'integer',
        h264_profile       => 'string(25)',
        h264_level         => 'string(25)',
        h264_keyframe_rate => 'float',
        audio_bitrate      => 'integer',
        audio_sample_rate  => 'string(25)',
        # The following are *not* the standard Zencoder output key names;
        # `thumb_` is prepended to make them more readable.
        thumb_number       => 'integer',
        thumb_interval     => 'integer',
        thumb_times        => 'string(255)',
    },
    defaults => {
        format        => 'mp4',
        quality       => '3',
        h264_profile  => 'main',
        audio_bitrate => '128',
    },
    audit   => 1,
    indexes => {
        blog_id => 1,
        label   => 1,
        status  => 1,
    },
    datasource  => 'z_profile',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Zencoder Output Settings Profile");
}

sub class_label_plural {
    MT->translate("Zencoder Output Settings Profiles");
}

sub ENABLE ()  { 1 }
sub DISABLE () { 2 }

sub list_properties {
    return {
        id => {
            auto    => 1,
            label   => 'ID',
            order   => 100,
            display => 'optional',
        },
        label => {
            base    => '__virtual.string',
            col     => 'label',
            label   => 'Label',
            order   => 200,
            display => 'default',
            html    => sub {
                my $prop = shift;
                my ( $obj, $app, $opts ) = @_;
                my $uri = $app->uri . '?__mode=zencoder.profile_edit&id=' . $obj->id;
                my $out = '<a href="' . $uri . '">' . $obj->label . '</a>';
                # Having the class "description" in place is enough to make the
                # field work with the Display Options.
                $out .= '<div class="description">' . $obj->description . '</div>';
                return $out;
            },
            sub_fields => [
                {
                    class   => 'description',
                    label   => 'Description',
                    display => 'default',
                },
            ],
        },
        format => {
            base    => '__virtual.string',
            col     => 'format',
            label   => 'Format',
            order   => 300,
            display => 'default',
        },
        width => {
            base    => '__virtual.string',
            col     => 'width',
            label   => 'Width',
            order   => 400,
            display => 'optional',
        },
        height => {
            base    => '__virtual.string',
            col     => 'height',
            label   => 'Height',
            order   => 500,
            display => 'optional',
        },
        max_frame_rate => {
            base    => '__virtual.integer',
            col     => 'max_frame_rate',
            label   => 'Max Frame Rate',
            order   => 600,
            display => 'optional',
        },
        keyframe_interval => {
            base    => '__virtual.integer',
            col     => 'keyframe_interval',
            label   => 'Keyframe Interval',
            order   => 700,
            display => 'optional',
        },
        quality => {
            base    => '__virtual.string',
            col     => 'quality',
            label   => 'Quality',
            order   => 800,
            display => 'optional',
        },
        h264_profile => {
            base    => '__virtual.string',
            col     => 'h264_profile',
            label   => 'H.264 Profile',
            order   => 900,
            display => 'optional',
        },
        h264_level => {
            base    => '__virtual.string',
            col     => 'h264_level',
            label   => 'H.264 Level',
            order   => 1000,
            display => 'optional',
        },
        h264_keyframe_rate => {
            base    => '__virtual.float',
            col     => 'h264_keyframe_rate',
            label   => 'Keyframe Rate (H.264 Only)',
            order   => 1100,
            display => 'optional',
        },
        audio_bitrate => {
            base    => '__virtual.string',
            col     => 'audio_bitrate',
            label   => 'Audio Bitrate',
            order   => 1200,
            display => 'optional',
        },
        audio_sample_rate => {
            base    => '__virtual.string',
            col     => 'audio_sample_rate',
            label   => 'Audio Sample Rate',
            order   => 1300,
            display => 'optional',
        },
        thumb_number=> {
            base    => '__virtual.string',
            col     => 'thumb_number',
            label   => 'Number of Thumbnails',
            order   => 1400,
            display => 'optional',
        },
        thumb_interval => {
            base    => '__virtual.string',
            col     => 'thumb_interval',
            label   => 'Thumbnail Time Interval',
            order   => 1500,
            display => 'optional',
        },
        thumb_times => {
            base    => '__virtual.string',
            col     => 'thumb_times',
            label   => 'Thumbnail Arbitrary Times',
            order   => 1600,
            display => 'optional',
        },
        blog_name => {
            base  => '__common.blog_name',
            label => sub {
                MT->app->blog
                    ? MT->translate('Blog Name')
                    : MT->translate('Website/Blog Name');
            },
            display   => 'none',
            site_name => sub { MT->app->blog ? 0 : 1 },
            order     => 1700,
        },
    };
}

# Create a bunch of default profiles for encoding. These defaults are likely to
# be used/popular, and are from Zencoder's encoding recommendations page.
# https://app.zencoder.com/docs/guides/encoding-settings
# Below, note that each profile doesn't necessarily have all keys present. If a
# key isn't present, Zencoder will fill in blanks with its defaults.
sub default_profiles {
    return {
        universal_smartphone => {
            label             => 'Universal smartphone (H.264 MP4)',
            description       => "This is a great starting profile for wide compatibility with modern smartphones. Plays on just about everything, though it doesn't take advantage of the higher resolutions and codec complexity possible on the newest crop of devices.",
            status            => Zencoder::Profile::ENABLE(),
            # url => 's3://output-bucket/output-file-name.mp4', # Sample URL
            height            => '320',
            width             => '480',
            max_frame_rate    => '30',
            quality           => '3',
            h264_level        => '3',
            audio_bitrate     => '128',
            audio_sample_rate => '44100',
        },
        universal_smartphone_high => {
            label             => 'Universal smartphone (high resolution, H.264 MP4)',
            description       => "This profile plays better on iPhone 4, iPad, Apple TV, new iPod Touch, Droid, PS3, and Xbox, by increasing the video resolution compared to the Universal Smartphone profile. The extra pixels are wasted on older iPhones though, and make for a video that won't play on Blackberry and some Android phones.",
            status            => Zencoder::Profile::DISABLE(),
            # url => 's3://output-bucket/output-file-name.mp4', # Sample URL
            height            => '480',
            width             => '640',
            max_frame_rate    => '30',
            quality           => '3',
            h264_level        => '3',
            audio_bitrate     => '128',
            audio_sample_rate => '44100',
        },
        advanced_smarthpone => {
            label             => 'Advanced smartphone (720P HD, H.264 MP4)',
            description       => "Newer iOS devices allow higher resolutions and higher encoding complexity (which means better compression). In particular, iPad and Apple TV users shouldn't have to watch 480x320 video on their beautiful screens, so it makes sense to provide a higher quality version if you want to provide a good experience to these users.",
            status            => Zencoder::Profile::DISABLE(),
            # url => 's3://output-bucket/output-file-name.mp4', # Sample URL
            height            => '720',
            width             => '1280',
            max_frame_rate    => '30',
            quality           => '4',
            h264_profile      => 'main',
            h264_level        => '3.1',
            audio_bitrate     => '160',
            audio_sample_rate => '48000',
        },
        html5_flash_native => {
            label             => 'HTML5, Flash (native resolution, MP4)',
            description       => '',
            status            => Zencoder::Profile::ENABLE(),
            # url => 's3://output-bucket/output-file-name.mp4', # Sample URL
        },
        html5_webm_native => {
            label             => 'HTML5, WebM (native resolution)',
            description       => '',
            status            => Zencoder::Profile::DISABLE(),
            # url => 's3://output-bucket/output-file-name.webm', # Sample URL
            format            => 'webm',
        },
        html5_ogg_native => {
            label             => 'HTML5, OGG (native resolution)',
            description       => '',
            status            => Zencoder::Profile::DISABLE(),
            # url => 's3://output-bucket/output-file-name.ogg', # Sample URL
            format            => 'ogg',
        },
    };
}

# Install the default output setting profiles. This is called when viewing the
# Zencoder Profiles listing screen.
sub install_default_profiles {
    my $app = shift;

    # Grab all the defined profiles, above.
    my $profiles = default_profiles();

    # Look at each profile and create it if necessary.
    foreach my $profile ( keys %$profiles ) {

        # Give up if a profile with this basename already exists. No point in
        # creating duplicates. The basename is only used for the default
        # profiles so it's a good way to check if the profile already exists.
        next if MT->model('zencoder_profile')->exist({ basename => $profile });

        my $obj = MT->model('zencoder_profile')->new();
        $obj->basename( $profile );
        $obj->blog_id( '0' ); # System-level

        my $profile_details = $profiles->{$profile};

        # Copy each field value into the corresponding column.
        while ( my ($field, $value) = each (%$profile_details) ) {
            $obj->$field( $value );
        }

        $obj->save or die $obj->errstr;
    }

    MT->log({
        category  => 'new',
        class     => 'zencoder',
        level     => MT->model('log')->INFO(),
        message   => 'Zencoder default Output Settings Profiles have been installed.',
    });
}

1;

__END__
