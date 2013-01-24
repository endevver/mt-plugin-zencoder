# Zencoder plugin for Movable Type

[Zencoder](http://zencoder.com) is a cloud-based audio and video encoding service from [Brightcove](http://brightcove.com). The Zencoder plugin for Movable Type integrates the Zencoder service with assets and the asset manager. A Zencoder account is required.

The Zencoder service makes it easy to transcode video to create video in the optimum format for a given user. That is, one use may prefer to watch your video in HD, another is satisfied with SD-quality, and a mobile user can be served an optimized video, too. All of these options serve to minimize buffering and bandwidth use while providing the best quality video to a given user. The Zencoder plugin makes this process easy by providing a simple interface to create the profiles necessary for the different types of user, and -- with one click -- letting you submit a video to Zencoder, which then returns transcoded video ready to use.

![Overview](https://github.com/endevver/mt-plugin-zencoder/blob/master/plugins/Zencoder/static/documentation/overview.png?raw=true)

Transcoded files from Zencoder and converted into Assets within Movable Type, ready to be used just like any other asset.


# Prerequisites

* Movable Type 4.x or 5.1x
* Zencoder account


# Installation

To install this plugin follow the instructions found here:

http://tinyurl.com/easy-plugin-install


# Configuration

The Zencoder plugin is configured at the system level. Visit Tools > Plugins > Zencoder and click Settings to find the configuration options.

Enter your Zencoder API key in the API Key field.

Zencoder places output files in an FTP location you designate. Configure the username, password, and path fields with the appropriate values.

Note that there are two path fields: FTP Destination Path and Server Destination Path. Both of these should contain absolute paths to the location Zencoder should place your transcoded files. The FTP user may have had a different root or home directory configured.

After Zencoder has completed processing a job and Movable Type has turned the new files from Zencoder into Assets, there is an opportunity to notify the user who submitted the files to be notified that they are complete: simply check the Notify Author checkbox.

Video files can be automatically submitted to Zencoder when they are uploaded. Enable this feature by clicking the Automatically Submit checkbox.

## Output Setting Profiles

Zencoder's encoding options can be configured to create an Output Setting Profile. Multiple Output Setting Profiles can be used to encode to a variety of outputs -- for example, set up two outputs to create both "HD" and "mobile" formatted output.

Several default Output Setting Profiles are automatically created. Create and modify additional Output Setting Profiles by choosing the Settings > Zencoder Profiles menu option at the System level (Preferences > Zencoder Profiles in MT4).

An Output Setting Profile can be specified with a variety of options that control the audio and picture quality as well as automatic thumbnail creation. Thorough descriptions accompany most fields; in particular note that not all fields require values, and leaving a field blank will often cause it to use the input video value, which is often the preferred choice.

Specify a Label and Description for the Output Profile you create; these fields can contain any value and are for your reference only. Set the status to enable or disable a given profile. All enabled profiles are used for any submitted asset.

## Zencoder Email Notification Template

A new template will be installed in Global Templates > Email Templates, called Zencoder Email Notification. If the Notify Author checkbox is enabled, this template is used to construct the body of the email sent to the author to notify them when a Zencoder job is complete.


# Use

## Submit an Asset to Zencoder

After uploading a video, submit it to Zencoder for transcoding to the enabled Output Setting Profiles. On the Manage Assets screen, select assets then choose Submit to Zencoder from the More Actions... dropdown menu. Alternatively, on the Edit Asset screen, choose the Submit to Zencoder from the sidebar Actions section.

If an asset has been successfully submitted to Zencoder you'll see a message indicating that the asset has been sent. Note that this indicates *only* that Zencoder has accepted your submission. Refer to the Zencoder control panel to see whether a job succeeds or fails, and why.

After Zencoder successfully transcodes your files and MT turns them into assets they are ready to use. Zencoder-built assets have a parent-child relationship and customized labels to make them easy to recognize. The asset first submitted to Zencoder is the parent, while any transcoded files are children (on the Edit Asset screen you'll see this in the Related Assets section). Similarly, any thumbnail images extracted are children to the transcoded video they were built from (again visible based on the Related Assets section on the Edit Asset screen). Labels for Zencoder-transcoded assets are made by assembling the parent asset's label with the Output Setting Profile used; examples: "Test video [HTML5, WebM (native resolution)]" and "Test video [HTML5, WebM (native resolution)] Thumbnail" for video and thumbnail assets.

## Upload a Video

You can easily bypass the above step and having your video automatically submitted to Zencoder by simply uploading a video (though be sure the Automatically Submit checkbox found in the Plugin Settings is enabled).

## Monitor Zencoder Encoding  Jobs

A simple interface to monitor the encoding jobs is available at the System Level, in Settings > Zencoder Jobs (Preferences > Zencoder Jobs in MT4). This view will let you see if there's a long queue or if something is stuck, for example.

Encoding jobs will automatically be removed from this table when they are complete. Deleting a job here will cause it to not complete (though Zencoder will still try to finish the job; be sure to also delete a job from the Zencoder control panel if you really want to cancel it).


# Templating

The Zencoder plugin doesn't provide any new template tags. Zencoder output becomes a Movable Type asset; just use the familiar asset tags to publish the output.

Zencoder does provide some extra metadata with a transcoded video, and that metadata is saved and available to publish using the `<mt:AssetProperty>` tag. Properties you can request include:

* `height`
* `width`
* `audio_bitrate_in_kbps`
* `audio_codec`
* `audio_sample_rate`
* `channels`
* `duration_in_ms`
* `format`
* `frame_rate`
* `video_bitrate_in_kbps`
* `video_codec`

Thumbnails from Zencoder are saved with the expected `image_width` and `image_height` properties, but no additional metadata.

Assets created by Zencoder will look like any other asset, however the label will be in a special format.

## Templating & Workflow

An easy way for authors to work with transcoded assets is to have a Custom Field where they can select the parent asset -- the one originally sent to Zencoder. All returned outputs become children to this parent asset, so publishing only those child assets will give the desired output.

The [Extra Tags plugin](https://github.com/endevver/mt-plugin-extratags) provides a block tag called [AssetFilter](https://github.com/endevver/mt-plugin-extratags#mtassetfiltermtassetfilter) which provides exactly the capability needed.

In this example, the CustomField is `VideoCF` and we want to publish the asset that used a custom Output Setting Profile called "Mobile Optimized." Remember, the Output Setting Profile label was appended to the child asset when Zencoder completed.

    <mt:VideoCFAsset>
        <mt:AssetID setvar="parent_asset_id">
    </mt:VideoCFAsset>

    <mt:AssetFilter parent="$parent_asset_id" label_filter="Mobile Optimized">
        <video src="<mt:AssetURL>" controls></video>
        <p>(Size: <mt:AssetProperty name="width">x<mt:AssetProperty name="height">)
    </mt:AssetFilter>


# License

This program is distributed under the terms of the GNU General Public License,
version 2.

# Copyright

Copyright 2013, [Endevver LLC](http://endevver.com). All rights reserved.
