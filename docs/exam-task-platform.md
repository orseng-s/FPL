# Exam Task Studio product plan

Exam Task Studio is a proposed web-based catalog for high school mathematics exam tasks. The first goal is to turn whole-exam PDFs into searchable, theme-tagged tasks so a teacher or student can build a focused practice document in a few clicks.

## Product goals

- Give students one place to find tasks by course, year, exam part, theme, subtheme, difficulty, and expected time.
- Let teachers build a printable study set by selecting individual tasks across several exams.
- Preserve the original exam provenance for every task, including PDF filename, page range, task number, season, and year.
- Keep the tagging workflow simple enough that new PDFs can be imported by an editor without writing code.
- Support future answer keys, solution videos, learning objectives, and analytics without changing the core task identity.

## Suggested information architecture

The catalog should use one metadata record per task. A task record should point to the original PDF and to a split PDF asset once that asset exists.

| Field | Purpose |
| --- | --- |
| `id` | Stable identifier such as `R1-2024-h-1-geometry-01`. |
| `year` and `season` | Makes it possible to filter by exam date and identify duplicates. |
| `course` | Course code such as `1P`, `1T`, `R1`, `R2`, `S1`, or `S2`. |
| `part` | `Part 1` or `Part 2`, so students know tool/calculator expectations. |
| `theme` and `subthemes` | Main browse dimensions, for example geometry, vectors, functions, probability, or statistics. |
| `difficulty` | Teacher-friendly level for sequencing practice. |
| `points` and `durationMinutes` | Helps generate balanced documents. |
| `sourcePdf`, `pageRange`, and `taskNumber` | Auditable link back to the original exam file. |
| `splitPdf` | Future path to the extracted single-task PDF. |
| `status` | Import status such as `Needs PDF split`, `Ready for review`, or `Published`. |

## PDF splitting workflow

1. Store original PDFs in a private source folder with normalized names such as `R1_2024_spring.pdf`.
2. Create or import a metadata row for each task, using the page range and task number from the original exam.
3. Split each task into a separate PDF file named after the stable task ID.
4. Review the extracted file to ensure diagrams, formulas, and subquestions were not cut off.
5. Publish only reviewed tasks to the student-facing catalog.
6. Keep answer keys and solutions as separate linked assets so the same task can be used for practice or assessment.

## MVP feature set

- Searchable web catalog with filters for course, year, theme, part, and difficulty.
- Task cards showing metadata, point value, estimated time, original PDF, and page range.
- A selection basket for building a custom study document.
- Print/export support so teachers can save the generated document as a PDF.
- A manifest export containing selected task IDs and source metadata.

## Later improvements

- Authenticated teacher accounts with saved collections.
- OCR-assisted task extraction and AI-assisted metadata suggestions.
- Side-by-side task and solution view with delayed reveal for students.
- Prerequisite tags and adaptive practice recommendations.
- Admin review queue for newly split PDFs.
- Norwegian and English interface text.
