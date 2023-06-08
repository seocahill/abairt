## Splitting big file

Caching might help but generally avoid longer than 10 minutes. Maybe set upload limit.

```
ffmpeg -i ~/Desktop/turas-siar-59.mp3 -ss 00:00:00 -t 00:10:00 -acodec copy ~/Desktop/turas-siar-59-a.mp3
```

## Asset caching

There’s another option for public files that let’s you bypass the proxy controller and still use get CDN caching. Let’s say your domain is example.com:

    Go to R2 and rename bucket to assets.example.com.
    Set that bucket as your active-storage bucket in storage.yml, set it to public: true
    Go into Cloudflare and create a CNAME for that bucket: assets.example.com → assets.example.com.s3.us-east-1.amazonaws.com
    Add cloudflare page rules to force caching in the subdomain;
    Finally, instead of passing blob to the image_tag, do this:
```
image_tag blob.url(virtual_host: true)
```
The end result will be something like this:

<img src="https://assets.example.com/ozf663sus62msm00fwcycqadnnqp"/>


## Limit Video size / split

Can use ffmpeg to split videos into separate recording or perhaps a size validation and instructions to people on how to do it?