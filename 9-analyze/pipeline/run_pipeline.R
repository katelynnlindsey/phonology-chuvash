# pipeline/run_pipeline.R
# ================================================================
# PIPELINE ORCHESTRATOR
#
# Runs the four pipeline stages in order and writes a provenance
# record of the run. This is the single entry point referenced by
# analyses/00_session_setup.R.
#
# USAGE
# -----
# Everything, from raw files to annotated levels:
#
#   source(here::here("9-analyze", "pipeline", "run_pipeline.R"))
#   run_pipeline()
#
# Re-run only the stages you actually invalidated (see WHAT TO RE-RUN
# below):
#
#   run_pipeline(from = 3)          # stages 3 and 4
#   run_pipeline(stages = 4)        # stage 4 only
#   run_pipeline(from = 2, to = 3)  # stages 2 and 3
#
# From a shell, without opening RStudio:
#
#   Rscript -e 'source("9-analyze/pipeline/run_pipeline.R"); run_pipeline()'
#
#
# WHAT TO RE-RUN AFTER CHANGING WHAT
# ----------------------------------
# Each stage reads only the outputs of the stage before it, so a change
# invalidates that stage and everything after it:
#
#   new/changed input files in 1-raw_data … 8-combine   -> from = 1
#   CLEANING thresholds, is_loan(), RUSSIAN/ENGLISH_SEQS -> from = 2
#   syllabify_ipa(), IPA_VOWELS, IPA_DIGRAPHS,
#     IPA_SONORITY, .max_onset_size()                    -> from = 3
#   VOWEL_RULES, VOWEL_CATEGORY_RULES, ACTIVE_RULE,
#     VOWEL_HEIGHT/BACKNESS/ROUND, classify_vowel()      -> from = 4
#
# Changing anything in config/phonology_params.R that is NOT in the list
# above (display colours, CORPORA metadata, labels) does not require a
# re-run.
#
#
# OUTPUTS
# -------
#   9-analyze/data/loaded/     stage 1
#   9-analyze/data/cleaned/    stage 2
#   9-analyze/data/leveled/    stages 3 and 4
#   9-analyze/data/run_log/    provenance record, one file per run
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

PIPELINE_STAGES <- c(
  "01_load_raw.R",
  "02_clean.R",
  "03_build_levels.R",
  "04_annotate.R"
)

RUN_LOG_DIR <- here::here("9-analyze", "data", "run_log")


#' Run a git subcommand in PROJECT_ROOT.
#'
#' Returns a list(ok = TRUE/FALSE, lines = character()). `ok` is FALSE if git
#' is absent OR exited non-zero, which matters: a failed git call must not be
#' allowed to look like a successful one reporting no output. (That is exactly
#' how a "working tree clean" claim gets fabricated from a git that never ran.)
#'
#' Note: no shQuote() on the path — system2() quotes its arguments itself, so
#' pre-quoting hands git a path with literal quote characters in it.
.git <- function(...) {
  if (!nzchar(Sys.which("git"))) return(list(ok = FALSE, lines = character()))
  out <- suppressWarnings(tryCatch(
    system2("git", c("-C", PROJECT_ROOT, ...), stdout = TRUE, stderr = FALSE),
    error = function(e) structure(character(), status = 127L)
  ))
  status <- attr(out, "status")
  list(ok = is.null(status) || identical(as.integer(status), 0L),
       lines = as.character(out))
}

#' Current git commit, or NA if git isn't available / this isn't a repo.
#' Recorded so a run log can be tied to the exact code that produced it.
.git_sha <- function() {
  r <- .git("rev-parse", "--short", "HEAD")
  if (!r$ok || !length(r$lines)) NA_character_ else r$lines[[1L]]
}

#' TRUE if the working tree has uncommitted changes, FALSE if clean,
#' NA if git could not tell us. A run log that says "dirty" cannot be
#' reproduced from its recorded SHA alone.
.git_dirty <- function() {
  r <- .git("status", "--porcelain")
  if (!r$ok) NA else length(r$lines) > 0L
}


#' Run the pipeline.
#'
#' @param from   first stage to run (1-4). Default 1.
#' @param to     last stage to run (1-4). Default 4.
#' @param stages explicit stage numbers, overriding `from`/`to`.
#'               e.g. stages = c(3, 4) or stages = 4.
#' @param log    write a provenance record to data/run_log/. Default TRUE.
#'
#' @return (invisibly) a data frame with one row per stage: stage name,
#'         elapsed seconds, and status.
run_pipeline <- function(from   = 1L,
                         to     = length(PIPELINE_STAGES),
                         stages = NULL,
                         log    = TRUE) {

  which_stages <- if (is.null(stages)) seq.int(from, to) else as.integer(stages)

  if (any(which_stages < 1L) || any(which_stages > length(PIPELINE_STAGES))) {
    stop("stage numbers must be between 1 and ", length(PIPELINE_STAGES))
  }
  if (is.null(stages) && from > to) {
    stop("`from` (", from, ") is after `to` (", to, ")")
  }

  sha   <- .git_sha()
  dirty <- .git_dirty()
  t_run <- Sys.time()

  cat("\n")
  cat("════════════════════════════════════════════════════════════\n")
  cat("  CHUVASH PHONOLOGY PIPELINE\n")
  cat("════════════════════════════════════════════════════════════\n")
  cat(sprintf("  Started      : %s\n", format(t_run, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("  Project root : %s\n", PROJECT_ROOT))
  cat(sprintf("  Git commit   : %s%s\n",
              if (is.na(sha)) "unavailable" else sha,
              if (isTRUE(dirty)) "  (UNCOMMITTED CHANGES PRESENT)" else ""))
  cat(sprintf("  Active rule  : %s — %s\n",
              ACTIVE_RULE, VOWEL_RULES[[ACTIVE_RULE]]$label))
  cat(sprintf("  Stages       : %s\n",
              paste(PIPELINE_STAGES[which_stages], collapse = ", ")))
  cat("════════════════════════════════════════════════════════════\n")

  if (isTRUE(dirty)) {
    warning("The working tree has uncommitted changes, so this run cannot ",
            "be reproduced from commit ", sha, " alone. Commit before any ",
            "run whose numbers will go into the manuscript.",
            call. = FALSE, immediate. = TRUE)
  }

  results <- vector("list", length(which_stages))

  for (i in seq_along(which_stages)) {
    stage_file <- PIPELINE_STAGES[[which_stages[[i]]]]
    stage_path <- here::here("9-analyze", "pipeline", stage_file)

    if (!file.exists(stage_path)) {
      stop("Stage script not found: ", stage_path)
    }

    cat(sprintf("\n\n>>> STAGE %d/%d: %s\n",
                i, length(which_stages), stage_file))
    cat(strrep("-", 60), "\n")

    t0 <- proc.time()[["elapsed"]]

    # local = new.env() so each stage gets a clean namespace and cannot
    # silently inherit an object left behind by the stage before it --
    # which is the failure mode that makes a pipeline work in one sitting
    # and break on a fresh session.
    source(stage_path, local = new.env(), echo = FALSE)

    elapsed <- proc.time()[["elapsed"]] - t0

    cat(sprintf("\n<<< %s finished in %s\n",
                stage_file, .fmt_duration(elapsed)))

    results[[i]] <- data.frame(
      stage        = stage_file,
      elapsed_secs = round(elapsed, 1),
      status       = "ok",
      stringsAsFactors = FALSE
    )
  }

  results   <- do.call(rbind, results)
  total     <- sum(results$elapsed_secs)

  cat("\n")
  cat("════════════════════════════════════════════════════════════\n")
  cat("  PIPELINE COMPLETE\n")
  cat("════════════════════════════════════════════════════════════\n")
  print(results, row.names = FALSE)
  cat(sprintf("\n  Total: %s\n", .fmt_duration(total)))
  cat("════════════════════════════════════════════════════════════\n\n")

  if (isTRUE(log)) {
    log_path <- .write_run_log(results, t_run, sha, dirty, total)
    cat("Run log written to:\n  ", log_path, "\n\n", sep = "")
  }

  invisible(results)
}


.fmt_duration <- function(secs) {
  if (secs < 60)   return(sprintf("%.1f s", secs))
  if (secs < 3600) return(sprintf("%.1f min", secs / 60))
  sprintf("%.2f hr", secs / 3600)
}


#' Write a plain-text provenance record for one pipeline run.
#'
#' Records what was run, from which commit, under which phonological
#' assumptions, with which package versions, and how big every output
#' file ended up. This is what lets a number in the manuscript be traced
#' back to the run that produced it.
.write_run_log <- function(results, t_run, sha, dirty, total) {

  dir.create(RUN_LOG_DIR, recursive = TRUE, showWarnings = FALSE)

  stamp    <- format(t_run, "%Y%m%d_%H%M%S")
  log_path <- file.path(RUN_LOG_DIR, paste0("run_", stamp, ".txt"))

  si <- utils::sessionInfo()

  con <- file(log_path, open = "wt", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  w <- function(...) cat(..., "\n", sep = "", file = con)

  w("CHUVASH PHONOLOGY PIPELINE — RUN LOG")
  w(strrep("=", 60))
  w("")
  w("Run started  : ", format(t_run, "%Y-%m-%d %H:%M:%S %Z"))
  w("Total time   : ", .fmt_duration(total))
  w("Project root : ", PROJECT_ROOT)
  w("Git commit   : ", if (is.na(sha)) "unavailable" else sha)
  w("Working tree : ",
    if (is.na(dirty)) "unknown"
    else if (dirty)   "DIRTY — uncommitted changes, run not reproducible from SHA"
    else              "clean")
  w("")

  w("PHONOLOGICAL ASSUMPTIONS")
  w(strrep("-", 60))
  w("ACTIVE_RULE    : ", ACTIVE_RULE, " — ", VOWEL_RULES[[ACTIVE_RULE]]$label)
  w("Strong vowels  : ", paste(active_strong(), collapse = " "))
  w("Weak vowels    : ", paste(active_weak(),   collapse = " "))
  w("")
  w("Cleaning thresholds:")
  for (nm in names(CLEANING)) {
    w("  ", format(nm, width = 18), ": ", paste(CLEANING[[nm]], collapse = ", "))
  }
  w("")

  w("STAGES RUN")
  w(strrep("-", 60))
  for (i in seq_len(nrow(results))) {
    w("  ", format(results$stage[i], width = 22),
      format(.fmt_duration(results$elapsed_secs[i]), width = 12),
      results$status[i])
  }
  w("")

  w("OUTPUT FILES")
  w(strrep("-", 60))
  for (d in c(PATHS$loaded_dir, PATHS$cleaned_dir, PATHS$leveled_dir)) {
    w("  ", sub(paste0(PROJECT_ROOT, "/"), "", d, fixed = TRUE), "/")
    fs <- sort(list.files(d, full.names = TRUE))
    if (!length(fs)) {
      w("      (empty)")
      next
    }
    for (f in fs) {
      w("      ", format(basename(f), width = 36),
        format(sprintf("%.1f MB", file.size(f) / 1024^2), width = 12),
        format(file.mtime(f), "%Y-%m-%d %H:%M:%S"))
    }
  }
  w("")

  w("SESSION INFO")
  w(strrep("-", 60))
  w("R version    : ", si$R.version$version.string)
  w("Platform     : ", si$platform)
  w("Locale       : ", Sys.getlocale("LC_CTYPE"))
  w("")
  w("Attached packages:")
  pkgs <- c(si$otherPkgs, si$loadedOnly)
  for (nm in sort(names(pkgs))) {
    w("  ", format(nm, width = 22), pkgs[[nm]]$Version)
  }

  log_path
}
