#!/usr/bin/perl -w

use HTTP::Request;
use LWP::UserAgent;

my $uri = 'http://local.genentech/mt/plugins/Zencoder/notification.cgi';
my $json = _sample_data();
my $req = HTTP::Request->new( 'POST', $uri );
$req->header( 'Content-Type' => 'application/json' );
$req->content( $json );

my $lwp = LWP::UserAgent->new;
$lwp->request( $req );



sub _sample_data {
    return <<SAMPLE;
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
    "label":"Universal smarthpone (H.264 MP4)",
    "file_size_in_bytes":17938,
    "width":160,
    "audio_bitrate_in_kbps":9,
    "id":235314,
    "total_bitrate_in_kbps":79,
    "state":"finished",
    "url":"ftp://example.com/Users/danwolfgang/Sites/genentech/IMG_0066.MOV",
    "md5_checksum":"7f106918e02a69466afa0ee014172496",
    "thumbnails": [
      {
        "label":"poster",
        "images":
        [
          {
            "url": "ftp://example.com//Users/danwolfgang/Sites/genentech/IMG_0066.png",
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
SAMPLE
}
