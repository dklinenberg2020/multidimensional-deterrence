# 03_dict_hits.R -- apply dict/econ_targets.csv to VIINA headlines.
# Terms are ICU regexes matched against lower-cased headline text; term_ua is applied
# to lang == "ua" headlines and term_ru to lang == "ru" (both to any other lang).
# Output: data/interim/viina_dict_hits.parquet (event_id x class flags),
#         output/dict_hits_by_class_month.csv, output/dict_hits_by_term.csv
source(here::here("R", "00_setup.R"))
ev   <- arrow::read_parquet(interim("viina_events.parquet"), col_select = c(event_id, date, month, lang, text, t_property_b))
dict <- readr::read_csv(here("dict", "econ_targets.csv"), show_col_types = FALSE) |>
  mutate(term_id = row_number())
txt  <- stri_trans_tolower(ev$text)
is_ua <- ev$lang == "ua"; is_ru <- ev$lang == "ru"

hit_mat <- sapply(seq_len(nrow(dict)), function(i) {
  h <- logical(length(txt))
  ua <- !is_ru; ru <- !is_ua
  h[ua] <- stri_detect_regex(txt[ua], dict$term_ua[i])
  h[ru] <- h[ru] | stri_detect_regex(txt[ru], dict$term_ru[i])
  h
})
colnames(hit_mat) <- paste0("term_", dict$term_id)

classes <- unique(dict$class)
cls <- map(classes, function(k) {
  ids_all  <- dict$term_id[dict$class == k]
  ids_spec <- dict$term_id[dict$class == k & dict$specific]
  tibble(!!paste0("hit_", k) := rowSums(hit_mat[, ids_all, drop = FALSE]) > 0,
         !!paste0("hitspec_", k) := if (length(ids_spec)) rowSums(hit_mat[, ids_spec, drop = FALSE]) > 0 else FALSE)
}) |> bind_cols()
hits <- bind_cols(ev |> select(event_id, date, month, lang, t_property_b), cls) |>
  mutate(hit_any  = if_any(starts_with("hit_")),
         hitspec_any = if_any(starts_with("hitspec_")),
         n_terms = rowSums(hit_mat),
         terms_hit = apply(hit_mat, 1, function(r) paste(which(r), collapse = ";")))
arrow::write_parquet(hits, interim("viina_dict_hits.parquet"))

by_cm <- hits |>
  group_by(month) |>
  summarise(n_events = n(),
            across(c(starts_with("hit_"), starts_with("hitspec_")), ~ sum(.x)),
            any_and_property = sum(hit_any & t_property_b == 1),
            .groups = "drop")
readr::write_csv(by_cm, out("dict_hits_by_class_month.csv"))

by_term <- dict |> mutate(n_hits = colSums(hit_mat),
                          n_hits_property = colSums(hit_mat & ev$t_property_b == 1))
readr::write_csv(by_term, out("dict_hits_by_term.csv"))

tot <- hits |> summarise(across(c(starts_with("hit_"), starts_with("hitspec_")), sum)) |> pivot_longer(everything())
print(tot, n = 30)
print(by_term |> select(term_id, term_ua, class, n_hits, n_hits_property), n = 50)
