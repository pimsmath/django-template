FROM python:3.9

ARG ENVIRONMENT

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

COPY app/Pipfile app/Pipfile.lock /app/
RUN pip install pipenv && pipenv install --system
RUN if [ "x${ENVIRONMENT}" = "xdevelopment" ] ; then pipenv install --system --dev ; fi
