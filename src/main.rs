use color_eyre::eyre::{Result, bail};
use maud::{html, PreEscaped};

#[derive(rust_embed::RustEmbed)]
#[folder = "src/dist/"]
pub struct Asset;

#[derive(Copy, Clone, PartialEq, Eq)]
pub enum Language {
    German,
    English,
}

impl std::fmt::Display for Language {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Language::German => f.write_str("de"),
            Language::English => f.write_str("en"),
        }
    }
}

impl Asset {
    pub fn md_page<S: AsRef<str>>(page: S, lang: Language) -> Result<PreEscaped<String>> {
        use pulldown_cmark::{html, Options, Parser};
        let options = Options::empty();
        let page: &str = page.as_ref();
        println!("Rendering {page}.{lang}.md");
        let page_data = match Asset::get(&format!("{page}.{lang}.md")) {
            Some(v) => v,
            None => bail!("Page not found"),
        };
        let page_data = page_data.data.as_ref();
        let mut page_data = std::str::from_utf8(page_data)?.to_owned();
        let includes = regex::Regex::new(r#"(?m)^<include /(?P<path>[^)>]*).[a-z]{2}.md>$"#).unwrap();
        if let Some(matches) = includes.captures(&&page_data.clone()) {
            println!("Have includes: {matches:?}");
            for path in matches.iter() {
                if let Some(path) = path {
                    let path = path.as_str();
                    if path.starts_with("<include") {
                        continue
                    }
                    println!("Processing include {path:?}");
                    let pstr = format!("<include /{path}.{lang}.md>");
                    page_data = page_data.replace(&pstr, &Asset::md_page(path, lang)?.0);
                }
            }
        }
        let parser = Parser::new_ext(&page_data, options);
        let mut html_output = String::new();
        html::push_html(&mut html_output, parser);
        Ok(PreEscaped(html_output))
    }
}

pub fn noscript_hdr() -> PreEscaped<String> {
    html! {
      noscript {
        style {
          "body { visibility: visible }"
        }
      }
    }
}

pub fn header<S: std::fmt::Display>(title: S) -> PreEscaped<String> {
    html! {
      head {
        meta charset="utf-8";
        meta name="viewport" content="width=device-width, initial-scale=1";
        meta http-equiv="x-ua-compatible" content="ie=edge";
        link rel="stylesheet" href="/terminal.min.css";
        link rel="stylesheet" href="/extra.css";

        title { (title.to_string()) }
        (noscript_hdr())
      }
    }
}

pub fn page<S: std::fmt::Display>(title: S, main: PreEscaped<String>) -> PreEscaped<String> {
    html! {
      (maud::DOCTYPE)
      html {
        (header(title))
        body {
          main {
            (main)
          }
        }
      }
    }
}

async fn privacy() -> impl axum::response::IntoResponse {
    (
        [(axum::http::header::CONTENT_TYPE, "text/html")],
        page("Privacy", Asset::md_page("privacy", Language::English).unwrap()).0,
    )
}

async fn imprint() -> impl axum::response::IntoResponse {
    (
        [(axum::http::header::CONTENT_TYPE, "text/html")],
        page("Imprint", Asset::md_page("imprint", Language::English).unwrap()).0,
    )
}

async fn static_file(uri: axum::http::Uri) -> impl axum::response::IntoResponse {
    StaticFile(uri.path().trim_start_matches('/').to_string())
}

pub struct StaticFile<T>(pub T);

impl<T> axum::response::IntoResponse for StaticFile<T>
where
    T: Into<String>,
{
    fn into_response(self) -> axum::response::Response {
        let path = self.0.into();

        match Asset::get(path.as_str()) {
            Some(content) => {
                let body = axum::body::boxed(axum::body::Full::from(content.data));
                let mime = mime_guess::from_path(path).first_or_octet_stream();
                axum::response::Response::builder()
                    .header(axum::http::header::CONTENT_TYPE, mime.as_ref())
                    .body(body)
                    .unwrap()
            }
            None => axum::response::Response::builder()
                .status(axum::http::StatusCode::NOT_FOUND)
                .body(axum::body::boxed(axum::body::Full::from("404")))
                .unwrap(),
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install()?;
    // build our application with a single route
    let app = axum::Router::new()
        .route("/", axum::routing::get(imprint))
        .route("/imprint", axum::routing::get(imprint))
        .route("/privacy", axum::routing::get(privacy))
        .route("/*file", axum::routing::get(static_file));
        
    println!("Running static pages server");

    axum::Server::bind(&"0.0.0.0:3077".parse()?)
        .serve(app.into_make_service())
        .await?;

    unreachable!()
}
