# Vibe Development Memory Bank

A file-based memory system to track development progress, ideas, and context for the Offline AI&ML Playground project.

## Structure

- `project-context/` - Core project information and architecture
- `issues/` - Known bugs, problems, and their solutions
- `ideas/` - Feature ideas and development thoughts
- `sessions/` - Development session notes and progress
- `code-snippets/` - Useful code patterns and solutions
- `resources/` - Links, references, and external resources

## Usage

Each memory is stored as a markdown file with:
- Clear title and date
- Tags for easy searching
- Structured content
- Cross-references to related memories

## Quick Access

Use `grep -r "tag:" MemoryBank/` to search by tags
Use `find MemoryBank/ -name "*.md" -exec grep -l "keyword" {} \;` to find specific content
