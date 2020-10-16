### Basler Camera

**NOTE**:

  * `Pixel Formats`

    | Camera Model | Tested Pixel Formats |
    |:------------:|:--------------------:|
    | Basler acA1920-40gc | mono8<br>ycbcr422_8<br>bayerrggb |
    | Basler acA1920-150uc | mono8<br>rgb8<br>bgr8<br>bayerbggr |

  * In case one wants to use any of the bayer pixel-format then `bayer2rgb` element needs to be used to covert raw bayer data to RGB. Refer the below pipeline.

    ```javascript
    {
      "type": "gstreamer",
      "pipeline": "gencamsrc serial=<DEVICE_SERIAL_NUMBER> pixel-format=bayerrggb width=1920 height=1080 ! bayer2rgb ! videoconvert ! video/x-raw,format=BGR ! appsink"
    }
    ```

  * In case one wants to use `mono8` image format or wants to work with monochrome camera then change the image format to mono8 in the pipeline. Since `gstreamer` ingestor expects a `BGR` image format, a single channel GRAY8 format would be converted to 3 channel BGR format.

    **Example pipeline to use `mono8` imageformat or work with monochrome basler camera:**

    ```javascript
    {
    "type": "gstreamer",
    "pipeline": "gencamsrc serial=<DEVICE_SERIAL_NUMBER> pixel-format=mono8 width=1920 height=1080 ! videoconvert ! video/x-raw,format=BGR ! appsink"
    }
    ```

  * In case one wants to enable resizing with basler camera `vaapipostproc` element can be used to specify the height and width parameter in the gstreamer pipeline.

    **Example pipeline to enable resizing  the frame to `600x600` with basler camera:**

    ```javascript
    {
      "type": "gstreamer",
      "pipeline": "gencamsrc serial=<DEVICE_SERIAL_NUMBER> pixel-format=ycbcr422_8 width=1920 height=1080 ! vaapipostproc height=600 width=600 ! videoconvert ! video/x-raw,format=BGR ! appsink"
    }
    ```

  * In case one wants to divert the colour space conversion to `GPU` for basler camera `vaapipostproc` can be used. This can be useful when the CPU% is maxing out due to the input ingestion stream.

    **Example pipeline to perform color space conversion from `YUY2 to BGRx` in GPU with `vaapipostproc` with basler camera:**

    ```javascript
    {
      "type": "gstreamer",
      "pipeline": "gencamsrc serial=<DEVICE_SERIAL_NUMBER> pixel-format=ycbcr422_8 width=1920 height=1080 ! vaapipostproc format=bgrx ! videoconvert ! video/x-raw,format=BGR ! appsink"
    }
    ```

  * In case multiple Basler cameras are connected use serial parameter to specify the camera to be used in the gstreamer pipeline in the video config file for camera mode.

  * In case frame read is failing when multiple basler cameras are used, use the interpacketdelay property to increase the delay between the
transmission of each packet for the selected stream channel. Depending on the number of cameras, use an appropriate delay can be set.

    TODO: **Example pipeline value to increase the interpacket delay

  `Basler camera hardware triggering`

  * If the camera is configured for triggered image acquisition, one can trigger image captures at particular points in time.

  * With respect to hardware triggering if the camera supports it then an electrical signal can be applied to one of the camera's input lines which can act as a trigger signal.

  * In order to configure the camera for hardware triggering, trigger mode must be enabled and the right trigger source depending on the Hardware Setup must be specified.

  * Trigger mode is enabled by setting the `continuous` property to `false` and based on the h/w setup, the right trigger source needs to be set for `triggersource` property

  `Validated test setup for basler camera hardware triggering`

  * In case of trigger mode the maximum time to wait for the hardware trigger to get generated can be set (in milliseconds) using the ` hwtriggertimeout` property.

  * In our test setup a python script was used to control a ModBus I/O module to generate a digital output to Opto-insulated input line(Line1) of the basler camera.

  * For testing the hardware trigger functionality Basler `acA1920-40gc` camera model had been used.

  >**Note**: Other triggering capabilities with different camera models are not tested.