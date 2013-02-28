package Zencoder::Plugin;

use strict;
use warnings;

use MT::Util qw( epoch2ts );

sub build_file_filter {
    my $cb   = shift;
    my $args = {};
    while (@_) {
        my $key   = shift;
        my $value = shift;
        $args->{$key} = $value;
    }

    # Look at the entry being published and find any assets associated with it.
    # If any associated asset is in-process with Zencoder then we do not want to
    # publish the entry because it's not ready yet. Reset the entry to be
    # scheduled to be published shortly in the future.
    if ( $args->{Entry} ) {
        my $e_id = $args->{Entry}->{column_values}->{id};
        my @object_assets = MT->model('objectasset')->load({
            object_id => $e_id,
            object_ds => 'entry',
        });

        foreach my $object_asset (@object_assets) {
            # If an asset used in this entry is also currently being processed
            # by Zencoder, then don't publish this page.
            if (
                MT->model('zencoder_job')->exist({
                    parent_asset_id => $object_asset->asset_id,
                })
            ) {
                my $obj  = MT->model('entry')->load( $e_id );
                my $blog = MT->model('blog')->load( $obj->blog_id );

                # Epoch is measured in seconds, so add five minutes to this
                # value to publish in the future.
                my $epoch = time;
                $epoch += 60 * 5;

                # Advance the publish time, and reset it to be a scheduled
                # Entry/Page. When RPT tries to republish, it will check if the
                # transcoded files are ready and publish.
                $obj->authored_on( epoch2ts($blog, $epoch) );
                $obj->status( MT->model('entry')->FUTURE() );
            }
        }
    }

    return 1;
}

1;

__END__
