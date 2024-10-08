#' @importFrom purrr compact
graphql_query <- function(json, ...) {
  file <- system.file(json, package = "shinyteamdashboard")
  query <- readChar(file, file.info(file)$size)
  gh::gh("POST /graphql", query = query, variables = compact(list(...)))
}

#' A wrapper around [DT::datatable] to change some defaults
#' @importFrom DT datatable formatDate
#' @importFrom utils modifyList
#' @importFrom purrr map_lgl possibly
#' @inheritParams DT::datatable
#' @export
# A datatable with some common options set
data_table <- function(data, options = list(), ..., filter = "top", style = "default", autoHideNavigation = TRUE, rownames = FALSE, escape = FALSE) {
  if (all(c("owner", "package", "issue") %in% colnames(data))) {
    data$issue <- glue::glue_data(data, '<a rel="noopener" target="_blank" href="https://github.com/{owner}/{package}/issues/{issue}">{issue}</a>')
  }
  if (all(c("owner", "package") %in% colnames(data))) {
    data$package <- glue::glue_data(data, '<a rel="noopener" target="_blank" href="https://github.com/{owner}/{package}">{package}</a>')
  }
  if ("owner" %in% colnames(data)) {
    data$owner <- glue::glue_data(data, '<a rel="noopener" target="_blank" href="https://github.com/{owner}">{owner}</a>')
  }
  default_opts <- list(pageLength = 1000,
    dom = "tip",
    columnDefs = list(
      list(targets = "_all", orderSequence = c("desc", "asc"))))

  options <- modifyList(options, default_opts)
  ret <- datatable(data,
    ...,
    options = options,
    filter = filter,
    style = style,
    autoHideNavigation = autoHideNavigation,
    rownames = rownames,
    escape = escape)
  if (any(map_lgl(data, inherits, "POSIXct")) > 0) {
    ret <- ret %>% formatDate(which(map_lgl(data, inherits, "POSIXct")), "toLocaleString")
  }
  ret
}

#' Plot a sparkline table
#' @inheritParams DT::datatable
#' @importFrom DT JS
#' @param sparkline_column The column to convert to a sparkline
#' @export
sparkline_table <- function(data, sparkline_column, ...) {
  table <- data_table(data, ...)
  table$x$options$columnDefs <- append(table$x$options$columnDefs,
      list(list(
        targets = sparkline_column - 1L,
        render = JS("
          function(data, type, row, meta) {
            return '<span class=spark>' + data + '</span>'
          }"))))
  table$x$options$fnDrawCallback <- JS("
      function (oSettings, json) {
        $('.spark:not(:has(canvas))').
        sparkline('html', {
          width: '100px',
          lineColor: '#DCAB49',
          fillColor: '#DBDED3',
          spotColor: '',
          minSpotColor: '',
          maxSpotColor: ''})
      }")
  table$dependencies <- append(table$dependencies, htmlwidgets::getDependency("sparkline"))
  table
}

`%|||%` <- function(x, y) if (length(x)) x else y

parse_datetime_8601 <- function(x) {
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ")
}

#' Get org logo
#'
#' @param org
#'
#' @return writes the avatar as a local file logo.png
#' @export
#'
#' @examples
#' get_org_logo("r-lib")
get_org_logo <- function(org){
  glue::glue("https://github.com/{org}.png") %>%
    magick::image_read() %>%
    magick::image_resize("48x48") %>%
    magick::image_write("logo.png")
}

#' Get org name
#'
#' @param org Org or user login
#'
#' @return string
#' @export
#'
#' @examples
#' get_org_name("r-lib")
#' get_org_name("jimhester")
get_org_name <- function(org){
  res <- graphql_query("login_name.graphql", org = org)
  res$data$repositoryOwner$name
}
