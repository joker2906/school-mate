# SchoolMate-App
![student mockup_112716](https://github.com/Yassin522/SchoolMate-App/assets/88105077/285ac72b-da7c-43c2-b980-3dbef4c23b75)

![teacher mockup_014955](https://github.com/Yassin522/SchoolMate-App/assets/88105077/0b2c3ae4-efe6-4741-995b-afb67101d482)

## Deploy on Render

This repository includes a Render Blueprint in [render.yaml](render.yaml).

### Included services

1. `schoolmate-api` (Web Service, Python/FastAPI)
2. `schoolmate-web` (Static Site, Flutter Web)

### Steps

1. In Render, click **New +** -> **Blueprint**.
2. Select this GitHub repository.
3. Confirm both services from `render.yaml`.
4. Set `JWT_SECRET` for `schoolmate-api` to a strong random value.
5. Deploy.

`schoolmate-api` uses `/health` as the health check endpoint.
