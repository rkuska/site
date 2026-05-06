# robert.kuska.xyz

Personal Jekyll site for https://robert.kuska.xyz.

## Building Locally

Use the Ruby version from `.ruby-version`, then run:

```sh
bundle install
bundle exec jekyll serve
```

Open http://127.0.0.1:4000/.

## Site Structure

* `/` is the About page.
* `/blog/` lists public blog posts.
* `/blog/tags/` lists tags for public blog posts.
* Individual post URLs are generated under `/blog/`.
* Posts with `private: true` are not shown in blog or tag listings.
* Archived posts are kept in `_archive/posts/` and are not published.

## Credits
Parchment is inspired from the resume theme
[Researcher](https://github.com/ankitsultana/researcher)

## License
[GNU GPL v3](LICENSE)
