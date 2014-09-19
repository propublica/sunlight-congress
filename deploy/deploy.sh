BRANCH="master"
REPO="git://github.com/sunlightlabs/congress.git"
DATETIME=`date +"%Y%m%d%H%M%S"`
HOME="/projects/congress-api"
SHARED_PATH="${HOME}/congress/shared"
VERSIONS_PATH="${HOME}/congress/versions"
VERSION_PATH="${VERSIONS_PATH}/${DATETIME}"
CURRENT_PATH="${HOME}/congress/current"
ENVIRONMENT="production"
KEEP=10

usage()
{
cat << EOF
usage: $0 options

This script deploys the Congress API. Does nothing by default. 

To execute standard deploy, use -s flag.

i.e.: deploy.sh -s

Otherwise, all options default to FALSE. Supplying individual flags will enable individual deploy steps.

OPTIONS:
  -s    Standard deployment (sets all flags to true)
  -a    Start unicorn
  -c    Set crontab
  -d    Delete old releases
  -h    Show this message
  -i    Create indexes
  -o    Stop unicorn
  -p    Install dependencies  
  -r    Clone repo
  -u    Set release as current
  -y    Make symlinks
EOF
}

while getopts ":sacdhiopruy" opt; do
  case $opt in
    \?)
      usage
      exit 1
      ;;
    s)
      echo "Executing standard deployment..."
      START_UNICORN=TRUE
      SET_CRONTAB=TRUE
      DELETE_OLD=TRUE
      INSTALL_DEPENDENCIES=TRUE
      CREATE_INDEXES=TRUE
      STOP_UNICORN=TRUE
      CLONE=TRUE
      SET_RELEASE_AS_CURRENT=TRUE
      MAKE_SYMLINKS=TRUE
      ;;
    a)
      START_UNICORN=TRUE
      ;;
    c)
      SET_CRONTAB=TRUE
      ;;
    d)
      DELETE_OLD=TRUE
      ;;
    h) 
      usage
      ;;      
    i)
      CREATE_INDEXES=TRUE
      ;;
    o)
      STOP_UNICORN=TRUE
      ;;
    p) 
      INSTALL_DEPENDENCIES=TRUE
      ;;
    r)
      CLONE=TRUE
      ;;      
    u)
      SET_RELEASE_AS_CURRENT=TRUE
      ;;
    y)
      MAKE_SYMLINKS=TRUE
      ;;
  esac
done

delete_old_releases() {
  echo "Deleting old releases..."
  DIRECTORIES_TO_KEEP=`ls -1t ${VERSIONS_PATH} | head -n ${KEEP}`
  ALL_VERSIONS=`ls -1 ${VERSIONS_PATH}`
  
  for version in $ALL_VERSIONS; do 
    DELETE_VERSION=true
    for keeper in $DIRECTORIES_TO_KEEP; do
      if [ "$keeper" -eq "$version" ]; then
        DELETE_VERSION=false
      fi
    done
    if [ $DELETE_VERSION = true ]; then
      echo "Deleting $VERSIONS_PATH/$version..."
      rm -rf $VERSIONS_PATH/$version
    fi
  done
}

start_unicorn() {
  echo "Starting unicorn..."
  cd ${CURRENT_PATH} && bundle exec unicorn -D -l ${SHARED_PATH}/congress.sock -c unicorn.rb
}

stop_unicorn() {
  echo "Trying to kill unicorn..."
  UNICORN_PROCESS=`cat ${SHARED_PATH}/unicorn.pid`
  kill ${UNICORN_PROCESS}
}

clone_repo() {
  echo "Cloning repo..."
  git clone -b ${BRANCH} ${REPO} ${VERSION_PATH}
}

make_symlinks() {
  echo "Making symlinks..."
  ln -sf ${SHARED_PATH}/config.yml ${VERSION_PATH}/config/config.yml
  ln -sf ${SHARED_PATH}/mongoid.yml ${VERSION_PATH}/config/mongoid.yml
  ln -sf ${SHARED_PATH}/config.ru ${VERSION_PATH}/config.ru
  ln -sf ${SHARED_PATH}/unicorn.rb ${VERSION_PATH}/unicorn.rb
  ln -sf ${SHARED_PATH}/unicorn.rb ${VERSION_PATH}/unicorn.rb
  ln -sf ${HOME}/data ${VERSION_PATH}/data
  ln -sf ${VERSION_PATH}/config/cron/scripts ${SHARED_PATH}/cron
}

install_dependencies() {
  echo "Installing dependencies..."  
  cd ${VERSION_PATH} && bundle install --local
  #Make sure this is correct pip path on server
  cd ${VERSION_PATH} && /projects/congress-api/.virtualenvs/congress/bin/pip install -r tasks/requirements.txt
}

create_indexes() {
  echo "Creating indexes..."
  cd ${VERSION_PATH} && rake create_indexes
}

set_release_as_current() {
  echo "Setting release as current..."
  rm -rf ${CURRENT_PATH} && ln -s ${VERSION_PATH} ${CURRENT_PATH}
}

set_crontab() {
  echo "Setting crontab...."
  cd ${CURRENT_PATH} && rake set_crontab environment=${ENVIRONMENT} current_path=${CURRENT_PATH}
}

if [ "$CLONE" = "TRUE" ]; then
  clone_repo
fi

if [ "$MAKE_SYMLINKS" = "TRUE" ]; then
  make_symlinks
fi

if [ "$INSTALL_DEPENDENCIES" = "TRUE" ]; then
  install_dependencies
fi

if [ "$CREATE_INDEXES" = "TRUE" ]; then
  create_indexes
fi

if [ "$SET_RELEASE_AS_CURRENT" = "TRUE" ]; then
  set_release_as_current
fi

if [ "$SET_CRONTAB" = "TRUE" ]; then
  set_crontab
fi

if [ "$STOP_UNICORN" = "TRUE" ]; then
  stop_unicorn
fi

if [ "$START_UNICORN" = "TRUE" ]; then
  start_unicorn
fi

if [ "$DELETE_OLD" = "TRUE" ]; then
  delete_old_releases
fi

echo "Deploy script complete."
