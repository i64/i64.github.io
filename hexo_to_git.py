from pathlib import Path


POST_PATH = Path("posts")
BODY_DELIM = '<!-- more -->'

TITLE_DELIM = 'title: '
DATE_DELIM = 'date: '

if __name__ == "__main__":
    for md_path in POST_PATH.glob('*.md'):
        images_folder = ''

        with md_path.open('r') as md:
            header, *body = md.read().split(BODY_DELIM)
        
        body = BODY_DELIM.join(body)

        splited_header: list[str] = header.split('\n')

        title = next(head[len(TITLE_DELIM):] for head in splited_header if head.startswith(TITLE_DELIM))
        date = next(head[len(DATE_DELIM):] for head in splited_header if head.startswith(DATE_DELIM))

        images_folder = ((images_path := POST_PATH / md_path.stem).is_dir() or images_folder) and images_path.as_posix()
        
        print(
            f"git add {md_path.as_posix()} {images_folder}"
        )
        print(
            f"GIT_COMMITTER_DATE='{date}' GIT_AUTHOR_DATE='{date}' git commit -m 'new post: {title}' "
        )

        with md_path.open('w') as md:
            md.writelines([
                f"# {title}",
                body
            ])