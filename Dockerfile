FROM ruby:2.2

RUN apt-get update

# Install pdftotext
RUN apt-get install poppler-data

# Install Python
RUN apt-get install -y python2.7 python2.7-dev
RUN python --version

# Install pip
RUN wget https://bootstrap.pypa.io/get-pip.py -O - | python
RUN pip --version

# Setup source/working directory
ADD . /usr/src/app
WORKDIR /usr/src/app

# Install dependencies
RUN bundle install
RUN pip install -r tasks/requirements.txt

CMD ["unicorn"]
