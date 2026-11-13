# Age on taking office for leaders of democracies since 1945, with US leaders
# aged 75 or older highlighted. Run from the repository root or from code/:
#   Rscript code/leader_age_distribution.R
# Writes figures/leader_age_distribution.png and .svg.

library(ggplot2)

# ---- paths -------------------------------------------------------------------
args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", args[grep("^--file=", args)])
root <- if (length(script)) normalizePath(file.path(dirname(script), "..")) else getwd()
dat <- read.csv(file.path(root, "data", "leaders_1945_2026.csv"), stringsAsFactors = FALSE)

# ---- style -------------------------------------------------------------------
font   <- "sans"        # change to an installed font, e.g. "Inter" or "Public Sans"
ink    <- "#1a1a1a"
ink2   <- "#55534e"
muted  <- "#8d8c87"
dotcol <- "#d6d4cf"
us_col <- "#E8A100"
gold   <- "#A86F00"

# ---- data --------------------------------------------------------------------
d <- dat[dat$include_in_plot, c("holder", "country", "office", "start_date", "age_at_start")]
d$us75 <- d$country == "United States" & d$age_at_start >= 75
d$kind <- ifelse(d$us75, "us", "other")

# Schumer is not in the data. He is shown as a hypothetical spell.
schumer_age <- as.numeric(as.Date("2027-01-03") - as.Date("1950-11-23")) / 365.2425
d <- rbind(d, data.frame(holder = "Chuck Schumer", country = "United States",
                         office = "Senate Majority Leader", start_date = "2027-01-03",
                         age_at_start = schumer_age, us75 = TRUE, kind = "schumer"))

n_spells   <- sum(d$kind != "schumer")
n_country  <- length(unique(d$country[d$kind != "schumer"]))
med        <- median(d$age_at_start[d$kind != "schumer"])
share_imp  <- with(dat[dat$include_in_plot, ], mean(!(birth_precision %in% "day") | !(date_precision %in% "day")))

# ---- stack dots: two columns per one-year age band ---------------------------
ncol_band <- 2
d$band <- floor(d$age_at_start)
d <- d[order(d$band, d$kind == "other", d$age_at_start), ]   # highlighted dots sit at the bottom
d$i   <- ave(seq_len(nrow(d)), d$band, FUN = seq_along) - 1
d$x   <- d$band + (d$i %% ncol_band + 0.5) / ncol_band
d$y   <- d$i %/% ncol_band + 0.5
top   <- max(d$y)

# ---- legend block for US leaders 75 or older ---------------------------------
office_label <- function(o) {
  o <- tolower(o)
  o[o == "speaker of the house"] <- "House speaker"
  o[o == "president"] <- "President"
  o <- sub("^senate", "Senate", o)
  o
}
us <- d[d$kind == "us", ]
us <- us[order(-us$age_at_start), ]
us$name <- sub(".* ", "", us$holder)
us$what <- paste0(office_label(us$office), ", ", substr(us$start_date, 1, 4))
sch <- d[d$kind == "schumer", ]
leg <- rbind(
  data.frame(name = us$name, age = us$age_at_start, what = us$what, kind = "us"),
  data.frame(name = "Schumer", age = sch$age_at_start, what = "if majority leader, Jan. 2027", kind = "schumer")
)
lx  <- 74.2                                   # left edge of the legend block
ly0 <- top * 0.66                             # first legend row
dy  <- top * 0.062
leg$y <- ly0 - (seq_len(nrow(leg)) - 1) * dy
leg$y[leg$kind == "schumer"] <- leg$y[leg$kind == "schumer"] - dy * 0.25
rule_y <- min(leg$y) - dy * 0.75

# oldest non-US spells get their own labels
oldest <- d[d$kind == "other", ]
oldest <- oldest[order(-oldest$age_at_start), ][1:2, ]
oldest$lab1 <- paste0(sub(".* ", "", oldest$holder), " ", sprintf("%.1f", oldest$age_at_start))
oldest$lab2 <- paste0(oldest$country, ", ", substr(oldest$start_date, 1, 4))
oldest$ly   <- c(top * 0.24, top * 0.17)

# ---- plot --------------------------------------------------------------------
title <- sprintf("Leaders of democracies typically take office at %d.\nAmerica keeps picking leaders who are nearly 80.", round(med))
subtitle <- sprintf(paste0("Each dot is one stint as president, prime minister, opposition leader or legislative party leader\n",
                           "in a democracy: %s stints in %d countries, for leaders in office since 1945."),
                    format(n_spells, big.mark = ","), n_country)
caption <- paste0(
  "Dots are stacked in one-year age bands. A change of title, such as majority to minority leader, starts a new stint. Democracy means a V-Dem electoral\n",
  "democracy index of 0.65 or higher when the stint began. Excludes acting, caretaker and interim holders, appointed or weaker upper chambers, House\n",
  "majority leaders, largely ceremonial presidencies, prime ministers serving under an executive president, and party groups outside a chamber's two\n",
  sprintf("largest. About %s of stints have a start or birth date known only to the month or year, so those ages can be off by up to a year. Sources: Wikipedia,\n",
          if (abs(share_imp - 0.2) < 0.05) "a fifth" else paste0(round(100 * share_imp), "%")),
  "parliament and party websites; V-Dem v16.")

pt  <- 2.55   # dot size
tsz <- 4.3    # annotation text size (mm)

p <- ggplot() +
  # axis line (drawn by hand so it stops at 91)
  annotate("segment", x = 28.6, xend = 91, y = 0, yend = 0, colour = muted, linewidth = 0.4) +
  # dots
  geom_point(data = d[d$kind == "other", ], aes(x, y), colour = dotcol, size = pt) +
  geom_point(data = d[d$kind == "us", ], aes(x, y), colour = us_col, size = pt + 0.6) +
  geom_point(data = d[d$kind == "schumer", ], aes(x, y), shape = 21, fill = "white",
             colour = us_col, stroke = 1.2, size = pt + 0.2) +
  # median
  annotate("segment", x = med, xend = med, y = max(d$y[d$band == floor(med)]) + 1.2, yend = top + 4.5,
           colour = ink2, linewidth = 0.4) +
  annotate("text", x = med + 0.5, y = top + 4.3, label = sprintf("Median: %d", round(med)),
           hjust = 0, vjust = 1, fontface = "bold", size = tsz + 0.3, colour = ink, family = font) +
  # legend block
  annotate("text", x = lx, y = ly0 + dy * 1.1, label = "U.S. leaders, 75 or older", hjust = 0,
           fontface = "bold", size = tsz, colour = gold, family = font) +
  geom_point(data = leg[leg$kind == "us", ], aes(x = lx + 0.2, y = y), colour = us_col, size = pt + 0.6) +
  geom_point(data = leg[leg$kind == "schumer", ], aes(x = lx + 0.2, y = y), shape = 21, fill = "white",
             colour = us_col, stroke = 1.2, size = pt + 0.2) +
  geom_text(data = leg, aes(x = lx + 0.9, y = y, label = name), hjust = 0, fontface = "bold",
            size = tsz, colour = ink, family = font) +
  geom_text(data = leg, aes(x = lx + 7.7, y = y, label = sprintf("%.1f", age)), hjust = 1, fontface = "bold",
            size = tsz, colour = ink, family = font) +
  geom_text(data = leg, aes(x = lx + 8.3, y = y, label = what), hjust = 0,
            size = tsz - 0.2, colour = ink2, family = font) +
  annotate("segment", x = lx, xend = 93.6, y = rule_y, yend = rule_y, colour = muted, linewidth = 0.4) +
  annotate("segment", x = 78.6, xend = 78.6, y = rule_y, yend = 2.6, colour = muted, linewidth = 0.4) +
  # oldest non-US spells
  geom_segment(data = oldest, aes(x = x, xend = x, y = y + 0.9, yend = ly - 2.6), colour = muted, linewidth = 0.4) +
  geom_text(data = oldest, aes(x = x, y = ly, label = lab1), hjust = 0.5, fontface = "bold",
            size = tsz - 0.3, colour = ink, family = font) +
  geom_text(data = oldest, aes(x = x, y = ly - 1.6, label = lab2), hjust = 0.5,
            size = tsz - 0.3, colour = ink2, family = font) +
  scale_x_continuous(breaks = seq(30, 90, 10), minor_breaks = seq(25, 95, 5),
                     limits = c(28.6, 93.8), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, top + 5), expand = c(0, 0)) +
  coord_fixed(ratio = 1 / ncol_band, clip = "off") +
  labs(title = title, subtitle = subtitle, caption = caption, x = "Age on taking office", y = NULL) +
  theme_minimal(base_family = font) +
  theme(
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.grid        = element_blank(),
    axis.text.y       = element_blank(),
    axis.ticks.x      = element_line(colour = muted, linewidth = 0.4),
    axis.ticks.length.x = unit(4, "pt"),
    axis.text.x       = element_text(size = 14, colour = ink2, margin = margin(t = 6)),
    axis.title.x      = element_text(size = 13, colour = ink2, face = "bold", margin = margin(t = 10)),
    plot.title        = element_text(size = 30, face = "bold", colour = ink, lineheight = 1.0,
                                     margin = margin(b = 12)),
    plot.subtitle     = element_text(size = 15, colour = ink2, lineheight = 1.15, margin = margin(b = 18)),
    plot.caption      = element_text(size = 10.5, colour = muted, hjust = 0, lineheight = 1.25,
                                     margin = margin(t = 22)),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    plot.margin       = margin(28, 30, 22, 28)
  )

out <- file.path(root, "figures", "leader_age_distribution")
dir.create(dirname(out), showWarnings = FALSE)
ggsave(paste0(out, ".png"), p, width = 13.3, height = 9.6, dpi = 200, bg = "white")
ggsave(paste0(out, ".svg"), p, width = 13.3, height = 9.6, bg = "white", device = grDevices::svg)
cat(sprintf("%d stints, %d countries, median %.1f\n", n_spells, n_country, med))
