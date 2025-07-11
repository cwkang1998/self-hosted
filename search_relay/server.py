from fastapi import FastAPI, Header, Body
from pydantic import BaseModel
from ddgs import DDGS

app = FastAPI()


class SearchRequest(BaseModel):
    query: str
    count: int


class SearchResult(BaseModel):
    link: str
    title: str | None
    snippet: str | None


@app.post("/search")
async def external_search(
    search_request: SearchRequest = Body(...),
    authorization: str | None = Header(None),
):
    query, count = search_request.query, search_request.count

    results = []
    try:
        search_results = DDGS().text(
            query, safesearch="moderate", max_results=count
        )

        results = [
            SearchResult(
                link=result["href"],
                title=result.get("title"),
                snippet=result.get("body"),
            )
            for result in search_results
        ]

    except Exception as e:
        print(f"Error during DuckDuckGo search: {e}")

    return results
