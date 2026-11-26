#!/bin/bash
set -e

: "${CTF_SECRET:?CTF_SECRET must be set}"
export CTF_SECRET

flag() { python3 /opt/generate_flags.py "$1"; }

DEPLOY_PASSWORD="CorpNimbus-Staging-88!"  # fixed/narrative -- discoverable via the git-history-only secrets.yml

echo "[*] Initializing Nimbus Freight web deployment..."

# --- Flag substitution, before anything gets committed to git ----------
mkdir -p /tmp/site/admin-x7f3
cp /opt/web/index.html /opt/web/status.html /opt/web/robots.txt /tmp/site/
cp /opt/templates/panel.html /tmp/site/admin-x7f3/panel.html
cp /opt/templates/secrets.yml /tmp/site/secrets.yml.staged

sed -i "s/FLAG1_PLACEHOLDER/$(flag 1)/" /tmp/site/index.html
sed -i "s/FLAG2_PLACEHOLDER/$(flag 2)/" /tmp/site/status.html
sed -i "s/FLAG3_PLACEHOLDER/$(flag 3)/" /tmp/site/robots.txt
sed -i "s/FLAG4_PLACEHOLDER/$(flag 4)/" /tmp/site/secrets.yml.staged
sed -i "s/FLAG5_PLACEHOLDER/$(flag 5)/" /tmp/site/admin-x7f3/panel.html

# --- A real git repo, built fresh every boot so per-team flags can -----
# --- live inside the actual commit blobs. secrets.yml is committed, -----
# --- then removed in a later commit -- recoverable only via the ---------
# --- exposed .git directory's history, not present in the live ----------
# --- working tree HEAD checks out to (which IS the served docroot). -----
export GIT_AUTHOR_NAME="deploy-bot" GIT_AUTHOR_EMAIL="deploy@nimbusfreight.internal"
export GIT_COMMITTER_NAME="deploy-bot" GIT_COMMITTER_EMAIL="deploy@nimbusfreight.internal"
export GIT_AUTHOR_DATE="2026-10-01T09:00:00" GIT_COMMITTER_DATE="2026-10-01T09:00:00"

rm -rf /var/www/html
mkdir -p /var/www/html
cd /var/www/html
git init -q -b main
cp /tmp/site/index.html /tmp/site/status.html /tmp/site/robots.txt .
mkdir -p admin-x7f3
cp /tmp/site/admin-x7f3/panel.html admin-x7f3/panel.html
cp /tmp/site/secrets.yml.staged secrets.yml
git add -A
git commit -q -m "Initial site + ops panel + deploy secrets"

export GIT_AUTHOR_DATE="2026-10-03T14:30:00" GIT_COMMITTER_DATE="2026-10-03T14:30:00"
git rm -q secrets.yml
git commit -q -m "Security cleanup before launch (remove secrets.yml)"

# Dumb-HTTP git clients (a real `git clone http://host/.git`, not just
# a tool that walks objects one at a time) need info/refs regenerated
# after every commit -- git commit doesn't do this on its own. Without
# it, a plain `git clone` 404s even though every object is genuinely
# sitting there fetchable.
git update-server-info

chown -R www-data:www-data /var/www/html

# --- Linux account (also the SSH foothold, password reused from the --
# --- git-history-only secret) --------------------------------------------
if ! id ops-deploy &>/dev/null; then
    useradd -m -s /bin/bash ops-deploy
fi
echo "ops-deploy:${DEPLOY_PASSWORD}" | chpasswd
mkdir -p /run/sshd
ssh-keygen -A

HOME_DIR="/home/ops-deploy"
echo "$(flag 6)" > "$HOME_DIR/user.txt"
cat << EOF > "$HOME_DIR/notes.txt"
To-do:
- Stop reusing the staging DB password as my own login.
- Ops gave me passwordless sudo on 'python3' for a one-off log-parsing
  script, ages ago. Never got around to asking for anything narrower.

Flag 7: $(flag 7)
EOF
chown -R ops-deploy:ops-deploy "$HOME_DIR"
chmod 600 "$HOME_DIR/user.txt"
chmod 644 "$HOME_DIR/notes.txt"

# --- A root-only file, reachable via the 'python3' GTFOBins trick -------
# --- before going for a full root shell (flag 8) -------------------------
cat << EOF > /var/log/deploy-audit.log
[audit] secrets.yml removal didn't scrub it from git history
[audit] ops-deploy password unchanged since onboarding

Flag 8: $(flag 8)
EOF
chown root:root /var/log/deploy-audit.log
chmod 600 /var/log/deploy-audit.log

# --- sudoers: ops-deploy may run 'python3' as root, no password ---------
cat << 'EOF' > /etc/sudoers.d/ops-deploy
ops-deploy ALL=(ALL) NOPASSWD: /usr/bin/python3
EOF
chmod 440 /etc/sudoers.d/ops-deploy

# --- Post-escalation checkpoint (flag 9) + final root flag (flag 10) --
mkdir -p /root
cat << EOF > /root/decommission_notes.txt
This deployment pipeline is getting replaced next quarter. Nobody's
touched the cleanup commit's actual git objects in months -- which is
probably how you got this far.

Flag 9: $(flag 9)
EOF
chmod 600 /root/decommission_notes.txt

echo "$(flag 10)" > /root/root.txt
chmod 600 /root/root.txt

service nginx start
exec /usr/sbin/sshd -D -e
