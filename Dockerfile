FROM python:3.8 as build
ENV PYTHONPATH /opt/application/
ENV PATH /opt/application/:$PATH
ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    UV_VERSION=0.9.13

WORKDIR /opt/application/

RUN mkdir -p /root/.ssh && chmod 0700 /root/.ssh
COPY dp_keys/ /root/.ssh/
RUN chmod -R 600 /root/.ssh/.*

RUN pip install "uv==$UV_VERSION"
# RUN poetry config virtualenvs.create false
COPY uv.lock .
COPY pyproject.toml  .
RUN uv sync --no-dev --python /usr/local/bin/python

FROM python:3.8-slim as project
COPY --from=build /opt/application/.venv/lib/python3.8/site-packages/ /usr/local/lib/python3.8/site-packages
COPY --from=build /opt/application/.venv/bin/gunicorn /usr/local/bin/gunicorn

RUN sed -i '1,2d' /usr/local/bin/gunicorn

RUN useradd -g users user
USER user
WORKDIR /opt/application/

ENV PYTHONPATH /usr/local/lib/python3.8/site-packages:/opt/application/

COPY project /opt/application/
COPY gunicorn.conf.py /opt/application/
CMD python $(which gunicorn) -c gunicorn.conf.py -b 0.0.0.0:8000 --log-level debug --access-logfile "-" --error-logfile "-" asgi:app
