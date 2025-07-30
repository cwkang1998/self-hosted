import pymupdf4llm
import pathlib


def main():
    # Get the full path to the input pdf
    pdf_file_path = input("Absolute path to your pdf:")
    if len(pdf_file_path) == 0:
        print("No path provided. Exiting...")
        return
    resolved_pdf_path = pathlib.Path(pdf_file_path)
    resolved_pdf_path = resolved_pdf_path.resolve()

    # Get the pages you are interested in
    pages = input(
        "Provide the start and end page number separated by a comma. Leave empty for full file:"
    )

    md_text = ""
    # Convert everything if pages not provided, else convert only the range between the pages.
    if len(pages) == 0:
        md_text = pymupdf4llm.to_markdown(resolved_pdf_path)
    else:
        # Get the start and end page number from the string
        page_idxs = list(map(lambda p: int(p.strip()), pages.split(",")))
        # Must have both start and end number, or else this wouldn't work
        if len(page_idxs) != 2:
            raise Exception(
                'You have to provide both start and end page number, separated by a comma. For example "78,121"'
            )
        md_text = pymupdf4llm.to_markdown(
            "input.pdf", pages=[i for i in range(page_idxs[0], page_idxs[1])]
        )

    # Write the output, default to a output.md file.
    print("Writing to output.md...")
    pathlib.Path("output.md").write_bytes(md_text.encode())
    
    print("Write complete.")


if __name__ == "__main__":
    main()
