package Zencoder::Job;

use strict;
use warnings;

use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
        id              => 'integer not null auto_increment',
        blog_id         => 'integer',
        parent_asset_id => 'integer',
        job_id          => 'integer',
        output_id       => 'integer',
        profile_label   => 'string(255)',
        message         => 'text',
    },
    audit   => 1,
    indexes => {
        blog_id         => 1,
        parent_asset_id => 1,
        job_id          => 1,
        output_id       => 1,
        profile_label   => 1,
    },
    datasource  => 'z_job',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Zencoder Encoding Job");
}

sub class_label_plural {
    MT->translate("Zencoder Encoding Jobs");
}

sub list_properties {
    return {
        id => {
            auto    => 1,
            label   => 'ID',
            order   => 100,
            display => 'optional',
        },
        job_id => {
            base    => '__virtual.integer',
            col     => 'job_id',
            label   => 'Zencoder Job ID',
            order   => 200,
            display => 'default',
        },
        parent_asset => {
            base    => '__virtual.string',
            col     => 'parent_asset_id',
            label   => 'Parent Asset',
            order   => 300,
            display => 'default',
            html    => sub {
                my $prop = shift;
                my ( $obj, $app, $opts ) = @_;
                my $asset = MT->model('asset')->load($obj->parent_asset_id);
                my $out = 'Unavailable'; # Deleted or otherwise unavailable?
                if ($asset) {
                    my $uri = $app->uri . '?__mode=view&_type=asset&blog_id=' 
                        . $asset->blog_id . '&id=' . $asset->id;
                    $out = '<a href="' . $uri . '">' . $asset->label . '</a>';
                }
                return $out;
            },
        },
        output_id => {
            base    => '__virtual.integer',
            col     => 'output_id',
            label   => 'Zencoder Output ID',
            order   => 400,
            display => 'default',
        },
        profile_label => {
            base    => '__virtual.string',
            col     => 'profile_label',
            label   => 'Output Setting Profile Label',
            order   => 500,
            display => 'default',
        },
        message => {
            base    => '__virtual.string',
            col     => 'message',
            label   => 'Error Message',
            order   => 600,
            display => 'default',
        },
        created_on => {
            base    => '__virtual.created_on',
            order   => 700,
            display => 'default',
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
            order     => 1500,
        },
    };
}

1;

__END__
