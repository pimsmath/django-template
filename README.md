# Django Environment Template

We have standardized on [docker-compose](https://docs.docker.com/compose/) to
provide reproducible django development environments.  Each environment consists
of a django application server (running via gunicorn) and a database server
running postgresql. Persistent storage is provided by a docker volume. We use
[pipenv](https://pypi.org/project/pipenv/) for python package management, and
provide the following base packages

  * django
  * gunicorn
  * psycopg2-binary
  * django-environ 
  * ipython [dev]

Application code is bind mounted into the container to allow for convenient
development, but it could be copied in for production use. `docker-compose` is
used for all management tasks including package installation, logging and
`django-admin` tasks.

## Starting a new project

To use this template, the only pre-flight step required is to generate values
for the secrets in the environment file. Specifically you need to provide values
for `POSTGRES_PASSWORD` and `DJANGO_SECRET_KEY`. e.g.
```bash
$ cp dot-env-template .env-development
$ python -c 'import secrets; print(f"POSTGRES_PASSWORD=\"{secrets.token_urlsafe()}\"")' >> .env-development
$ python -c 'import secrets; print(f"DJANGO_SECRET_KEY=\"{secrets.token_urlsafe()}\"")' >> .env-development
...
```

You should now be able to start everything with.
```bash
$ docker-compose up -d
```
Your webserver should now be running on
[http://127.0.0.1:8000](http://127.0.0.1:8000)


### Developing a new project

Almost all interactions should be prefixed by `docker-compose`. For example, to
install new packages via `pipenv`, you would run

```bash
$ docker-compose exec web pipenv install django-environ==0.4.5
```

This would install
[django-environ](https://django-environ.readthedocs.io/en/latest/) to an
ephemeral virtualenv but it will also make a persistent update to the `Pipfile`.
Generally, after installing a package or making a configuration change you
should restart the app with

```bash
$ docker-compose down && docker-compose up -d --build
```
The `--build` flag will reinstall everything it finds in the `Pipfile`.


Similarly, you can run `django-admin` or `python manage.py` tasks inside the
app container via `docker-compose`, e.g.

```bash
$ docker-compose exec web python manage.py makemigrations
$ docker-compose exec web python manage.py migrate
```

You can get direct access to the database container with

```bas
$ source .env-development
$ docker-compose exec db psql -U $POSTGRES_USER
```

And you can get access to the interactive shell with
```bash
$ docker-compose exec web python manage.py shell
```
If ipython is installed and you are running a development environment this
should automatically select ipython as your management shell.


## Building a new Base Environment

**N.B. In general you should not need the information in this section. If you
want to new django project use template above to start a new project. The steps
here are only relevant if you want to build a new _template_**.

Building new template involves some awkward dependencies. In general we want to
keep everything locked up in docker and fully specified in our `Pipfile` but we
needua working environment to generate that. Additionally, our docker-compose
file assumes that we already have a running django project that we want to
modify. One way around these dependencies is to install some of them locally
(outside of docker) and bootstrap the necessary files. For the sake of
completeness and reproducibility we will avoid that and use docker for
everything. With the steps below, it should be possible to start from the base
python3 docker image and bootstrap everything else we need.


To build our environment from scratch, the main requirement is to construct
working `Pipenv` and `Pipenv.lock` files. In most cases these will already be
available to you, but the They should provide the following base
packages which are needed by our docker image and `docker-compose.yml`.

  * django
  * psycopg2-binary
  * gunicorn
  * django-environ

If they don't exist (or if you want to rebuild them from scratch, e.g. a major
update), they can be generated from the latest Python docker image as follows

```bash
$ mkdir app
$ docker run --rm -v $(pwd)/app:/app -w /app python:3.9 bash -c \
    "pip install pipenv && \
    pipenv install django==3.1.6 \
    psycopg2-binary==2.8.6 \
    django-environ==0.4.5 \
    gunicorn==20.0.4 && \
    pipenv install --dev ipython"
```

That should generate `python3/Pipfile` and `python3/Pipfiles.lock` files with
those packages.

If you also want to generate a completely fresh django config, you can do
```
$ docker run --rm -v $(pwd)/app:/app -w /app python:3.9 bash -c \
    "pip install pipenv && pipenv install && \
    pipenv run django-admin startproject config ."
```

You will need to update the default django config to configure the database and
read in the environment variables. Here is an example of the modifications
needed on top of the stock django=3.1.6 config.

```diff
diff --git a/app/config/settings.py b/app/config/settings.py
index ea3ec3a..2bf9c34 100644
--- a/app/config/settings.py
+++ b/app/config/settings.py
@@ -9,6 +9,8 @@ https://docs.djangoproject.com/en/3.1/topics/settings/
 For the full list of settings and their values, see
 https://docs.djangoproject.com/en/3.1/ref/settings/
 """
+import environ
+env = environ.Env()

 from pathlib import Path

@@ -20,10 +22,10 @@ BASE_DIR = Path(__file__).resolve().parent.parent
 # See https://docs.djangoproject.com/en/3.1/howto/deployment/checklist/

 # SECURITY WARNING: keep the secret key used in production secret!
-SECRET_KEY = 'mdzbcp)766!!9ktudu#pl8ihz(qn6z59vo=$gp(mio9mcx&3)i'
+SECRET_KEY = env('DJANGO_SECRET_KEY')

 # SECURITY WARNING: don't run with debug turned on in production!
-DEBUG = True
+DEBUG = env('DJANGO_DEBUG', default=False)

 ALLOWED_HOSTS = []

@@ -74,10 +76,7 @@ WSGI_APPLICATION = 'config.wsgi.application'
 # https://docs.djangoproject.com/en/3.1/ref/settings/#databases

 DATABASES = {
-    'default': {
-        'ENGINE': 'django.db.backends.sqlite3',
-        'NAME': BASE_DIR / 'db.sqlite3',
-    }
+    'default': env.db(),
 }


@@ -118,3 +117,15 @@ USE_TZ = True
 # https://docs.djangoproject.com/en/3.1/howto/static-files/

 STATIC_URL = '/static/'
+
+SECURE_BROWSER_XSS_FILTER = env('DJANGO_BROWSER_XSS_FILTER', default=False)
+X_FRAME_OPTIONS = env('DJANGO_X_FRAME_OPTIONS', default='DENY')
+SECURE_SSL_REDIRECT = env('DJANGO_SECURE_SSL_REDIRECT', default=False)
+SECURE_HSTS_SECONDS = env('DJANGO_SECURE_HSTS_SECONDS', default=0)
+SECURE_HSTS_INCLUDE_SUBDOMAINS = env('DJANGO_SECURE_HSTS_INCLUDE_SUBDOMAINS', default=False)
+SECURE_HSTS_PRELOAD = env('DJANGO_SECURE_HSTS_PRELOAD', default=False)
+SECURE_CONTENT_TYPE_NOSNIFF = env('DJANGO_SECURE_CONTENT_TYPE_NOSNIFF', default=True)
+SESSION_COOKIE_SECURE = env('DJANGO_SESSION_COOKIE_SECURE', default=False)
+CSRF_COOKIE_SECURE = env('DJANGO_CSRF_COOKIE_SECURE', default=False)
+SECURE_REFERRER_POLICY = env('DJANGO_SECURE_REFERRER_POLICY', default='same-origin')
+SECURE_PROXY_SSL_HEADER = env('SECURE_PROXY_SSL_HEADER', default=('HTTP_X_FORWARDED_PROTO', 'https'))
```


