# 02_size_job.R -- monthly event counts: all, t_property_b, and each actor flag.
# Output: output/monthly_counts.csv, output/monthly_counts.png
source(here::here("R", "00_setup.R"))
ev <- arrow::read_parquet(interim("viina_events.parquet"))

actor_flags <- grep("^a_.*_b$", names(ev), value = TRUE)
mc <- ev |>
  group_by(month) |>
  summarise(n_all = n(),
            n_property = sum(t_property_b == 1, na.rm = TRUE),
            # A flag that is NA for >50% of a month is reported as NA, not 0
            # (a_*_init are unpopulated for most of 2022-2024; see NOTES.md).
            across(all_of(actor_flags), ~ if (mean(is.na(.x)) > 0.5) NA_integer_ else sum(.x == 1, na.rm = TRUE), .names = "n_{.col}"),
            across(all_of(actor_flags), ~ mean(is.na(.x)), .names = "na_share_{.col}"),
            n_property_rus_init = if (mean(is.na(a_rus_init_b)) > 0.5) NA_integer_ else sum(t_property_b == 1 & a_rus_init_b == 1, na.rm = TRUE),
            n_property_ukr_init = if (mean(is.na(a_ukr_init_b)) > 0.5) NA_integer_ else sum(t_property_b == 1 & a_ukr_init_b == 1, na.rm = TRUE),
            model_version = paste(sort(unique(viina_version)), collapse = ";"),
            .groups = "drop")
readr::write_csv(mc, out("monthly_counts.csv"))
log_gap("02_size_job", "months with a_rus_init_b unpopulated (>50% NA)", sum(is.na(mc$n_a_rus_init_b)), "reported NA in monthly_counts.csv")

long <- mc |> select(month, n_all, n_property, n_a_rus_init_b, n_a_ukr_init_b) |>
  pivot_longer(-month, names_to = "series", values_to = "n") |>
  filter(!is.na(n), n > 0) |>   # unpopulated / zero months are gaps, not zeros, on a log axis
  mutate(series = recode(series, n_all = "All events", n_property = "t_property = 1",
                         n_a_rus_init_b = "Russian-initiated (a_rus_init)",
                         n_a_ukr_init_b = "Ukrainian-initiated (a_ukr_init)"))
p <- ggplot(long, aes(month, n, colour = series)) + geom_line(linewidth = 0.7) + geom_vline(xintercept = as.Date("2025-01-01"), linetype = 3) +
  annotate("text", x = as.Date("2025-01-01"), y = 30, label = " model/source break", hjust = 0, size = 3) +
  scale_y_log10(labels = scales::comma) +
  labs(x = NULL, y = "Event reports per month (log scale)", colour = NULL,
       title = "VIINA 2.0 event reports by month",
       caption = sprintf("VIINA commit %s. Raw event reports (not 1-per-day filtered). Initiator flags unpopulated May 2022-Dec 2024.", substr(VIINA_COMMIT, 1, 7))) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave(out("monthly_counts.png"), p, width = 9, height = 5, dpi = 150)
print(mc |> select(month, n_all, n_property, n_a_rus_init_b, n_a_ukr_init_b), n = 100)
