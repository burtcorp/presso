# Presso

Presso is a small JRuby library for extracting and creating zip
archives. It wraps `java.util.zip` in a nice package.

## Example usage:

```ruby
presso = Presso.new

# create a zip archive of the pictures folder contents
presso.zip_dir('pictures.zip', 'pictures')

# unzip pictures.zip into photos directory
presso.unzip('pictures.zip', 'photos')
```
