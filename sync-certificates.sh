#!/bin/bash

# Variables
REMOTE_SERVER="remotesslserver.serverclienti.com"
REMOTE_CERT_PATH="/etc/letsencrypt/live/serverclienti.com/cert.pem"
REMOTE_KEY_PATH="/etc/letsencrypt/live/serverclienti.com/privkey.pem"
REMOTE_FULLCHAIN_PATH="/etc/letsencrypt/live/serverclienti.com/fullchain.pem"
REMOTE_CHAIN_PATH="/etc/letsencrypt/live/serverclienti.com/chain.pem"
LOCAL_CERT_PATH="/etc/apache2/ssl/star.serverclienti.com.crt"
LOCAL_KEY_PATH="/etc/apache2/ssl/star.serverclienti.com.key"
LOCAL_CHAIN_PATH="/etc/apache2/ssl/intermediate.crt"
LOCAL_PEM="/etc/apache2/ssl/star.serverclienti.com.pem"
TEMP_CERT_PATH="/tmp/fullchain.pem"
TEMP_KEY_PATH="/tmp/privkey.pem"
PORT=22 # SSH Port to use

# Functions to restart services
# adjust/adapt accordingly, use servicectl for newer OS
restart_services() {
    echo "Restarting services..."
#    service nginx restart
#    service atlbitbucket restart
#    service postfix restart
    service apache2 restart
#    service courier-authdaemon restart
#    service courier-imap restart
#    service courier-imap-ssl restart
#    service courier-pop restart
#    service courier-pop-ssl restart
    echo "All services restarted."
}

# Securely download the certificate from the remote server
# make sure to have installed the SSH keys accordingly
# limit the SSH keys in the .ssh/authorized_keys file using one of those regexp templates:
# command="if [[ \"$SSH_ORIGINAL_COMMAND\" =~ ^scp[[:space:]]-f[[:space:]]/etc/letsencrypt/.? ]]; then $SSH_ORIGINAL_COMMAND ; else echo ERROR Access Denied $SSH_ORIGINAL_COMMAND; fi",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa AA.. or
# command="if [[ \"$SSH_ORIGINAL_COMMAND\" =~ ^scp[[:space:]]-f[[:space:]]--[[:space:]]/etc/letsencrypt/.? ]]; then $SSH_ORIGINAL_COMMAND ; else echo ERROR Access Denied $SSH_ORIGINAL_COMMAND; fi",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-rsa AA..
echo "Downloading certificate from remote server..."
scp -P $PORT "$REMOTE_SERVER:$REMOTE_FULLCHAIN_PATH" "$TEMP_CERT_PATH"

# Check if the certificate was downloaded successfully
if [ ! -f "$TEMP_CERT_PATH" ]; then
    echo "Failed to download the certificate. Exiting..."
    exit 1
fi

# Check if the local certificate exists
if [ ! -f "$LOCAL_CERT_PATH" ]; then
    echo "Local certificate not found. Copying new certificate..."
    cp "$TEMP_CERT_PATH" "$LOCAL_CERT_PATH"
#    cp "$TEMP_CERT_PATH" "$LOCAL_CERT_PATH2" # do the same for the second location

    # Download and securely copy the private key
    echo "Copying private key..."
    scp -P $PORT "$REMOTE_SERVER:$REMOTE_KEY_PATH" "$TEMP_KEY_PATH"
    chmod 600 "$TEMP_KEY_PATH" # Set correct permissions to secure the key
    mv "$TEMP_KEY_PATH" "$LOCAL_KEY_PATH" # Move key to the correct location
    chmod 600 "$LOCAL_KEY_PATH" # Ensure private key has correct permissions
#    cp -rdp "$LOCAL_KEY_PATH" "$LOCAL_KEY_PATH2" # copy the key also to the second location

    # Download chain
    scp -P $PORT "$REMOTE_SERVER:$REMOTE_CHAIN_PATH" "$LOCAL_CHAIN_PATH"
#    cp -rdp "$LOCAL_CHAIN_PATH" "$LOCAL_CHAIN_PATH2"

    # create local PEM
    cat "$LOCAL_KEY_PATH" "$LOCAL_CERT_PATH" > "$LOCAL_PEM"

    restart_services
    rm "$TEMP_CERT_PATH"
    exit 0
fi

## Compare modification times of the certificates
#REMOTE_CERT_MOD=$(stat -c %Y "$TEMP_CERT_PATH")
#LOCAL_CERT_MOD=$(stat -c %Y "$LOCAL_CERT_PATH")
#echo "Modification time of remote certificate is $REMOTE_CERT_MOD, modification time of local certificate is $LOCAL_CERT_MOD"

# Generate MD5 checksums
REMOTE_CERT_MD5=$(md5sum "$TEMP_CERT_PATH" | awk '{ print $1 }')
LOCAL_CERT_MD5=$(md5sum "$LOCAL_CERT_PATH" | awk '{ print $1 }')
echo "MD5 of remote certificate is $REMOTE_CERT_MD5, MD5 of local certificate is $LOCAL_CERT_MD5"

## If the downloaded certificate is newer
#if [ "$REMOTE_CERT_MOD" -gt "$LOCAL_CERT_MOD" ]; then
# Compare MD5 checksums of the certificates
if [ "$REMOTE_CERT_MD5" != "$LOCAL_CERT_MD5" ]; then
#    echo "Newer certificate found. Replacing the local certificate and restarting services..."
    echo "Certificates differ. Replacing the local certificate and key, then restarting services..."
    cp "$TEMP_CERT_PATH" "$LOCAL_CERT_PATH"
 #   cp "$TEMP_CERT_PATH" "$LOCAL_CERT_PATH2"

    # Download and securely copy the private key
    echo "Copying private key..."
    scp -P $PORT "$REMOTE_SERVER:$REMOTE_KEY_PATH" "$TEMP_KEY_PATH"
    chmod 600 "$TEMP_KEY_PATH" # Set correct permissions to secure the key
    mv "$TEMP_KEY_PATH" "$LOCAL_KEY_PATH" # Move key to the correct location
    chmod 600 "$LOCAL_KEY_PATH" # Ensure private key has correct permissions
 #   cp -rdp "$LOCAL_KEY_PATH" "$LOCAL_KEY_PATH2" # copy the key also to the second location

    # Download chain
    scp -P $PORT "$REMOTE_SERVER:$REMOTE_CHAIN_PATH" "$LOCAL_CHAIN_PATH"
 #   cp -rdp "$LOCAL_CHAIN_PATH" "$LOCAL_CHAIN_PATH2"

    # create local PEM
    cat "$LOCAL_KEY_PATH" "$LOCAL_CERT_PATH" > "$LOCAL_PEM"


    restart_services
else
    echo "Local certificate is up to date. No changes needed."
fi

# Clean up the temporary certificate file
rm "$TEMP_CERT_PATH"

exit 0
