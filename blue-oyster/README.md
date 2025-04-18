### Blue-Oyster Honeypot Configuration

---

As part of the honeypot configuration, a dedicated *trap user* should be created on the host system. This user acts as a decoy entry point for potential attackers. Upon SSH login, the user is immediately redirected into a Docker container, effectively isolating their session. The following steps describe how to set up this user and configure their environment:

1. **Create the Trap User:**
   Use administrative privileges to add a user (e.g., `trapuser`) with a home directory and bash shell:

   ```bash
   sudo useradd -m -s /bin/bash trapuser
   ```

2. **Create a Logging Directory:**
   Set up a directory for logging SSH connection metadata:
   ```bash
   mkdir -p /home/trapuser/blue-oyster-log
   chown trapuser:trapuser /home/trapuser/blue-oyster-log
   ```
　　While you're at it, you might as well suppress the default login banners to keep things neat and inconspicuous:


   ```bash
   touch /home/trapuser/.hushlogin
   ```

   This minor touch helps maintain the illusion of a minimal and unremarkable shell environment, subtly increasing the honeypot’s credibility.

3. **Configure `.bashrc`:**
   Modify the `.bashrc` file in the trap user's home directory as follows:

   ```bash
   # /home/trapuser/.bashrc

   LOGFILE="$HOME/blue-oyster-log/ssh-client.log"
   if [[ -n "$SSH_CONNECTION" ]]; then
       echo "SSH login from: $(echo $SSH_CONNECTION | awk '{print $1}') at $(date)" >> "$LOGFILE"
   fi
   docker exec -ti blue-oyster /bin/bash
   exit
   ```

With this configuration, any SSH session initiated as `trapuser` will automatically log the client’s IP address and seamlessly redirect the user into the `blue-oyster` Docker container. Within the container, all interactions are closely monitored and recorded, while the user remains unaware that they have been isolated from the actual host system.

This mechanism effectively lures unauthorized users into a controlled environment under the guise of a normal shell session, allowing for the deployment of both psychological and technical countermeasures.


---

Subsequently, the `exit` command may be used to terminate the session.

Once inside the container environment, all user-issued commands will be systematically recorded. It is therefore advisable to exercise caution in any actions undertaken. Furthermore, should an excessive number of commands be executed within a brief time span, the system may initiate the unsolicited transmission of pseudo-random data streams.

This design serves to exploit user curiosity by enticing individuals to execute the aforementioned `docker exec` command. Upon doing so, they are directed into a honeypot environment wherein a sequence of deliberately disorienting and inconvenient behaviors will be triggered.

---

### Notable Mechanisms within `.bashrc`

**Redirection to `/bin/bash`:**
The `.bashrc` script is configured such that invocation of an interactive shell via `docker exec -ti blue-oyster /bin/bash` will initiate logging of all user interactions. Additionally, conditional logic may trigger further scripted responses based on command usage patterns.

**Injection of Random Data upon Exceeding Command Threshold:**
Once the user surpasses a predefined command execution threshold (`max_count`), the system is designed to output a continuous stream of data from `/dev/urandom` to the terminal. This behavior is intended to induce confusion and simulate environmental instability.

**Interception of the `exit` Command:**
In the event that the user attempts to terminate the session via the `exit` command, the system may respond with an unexpected message (e.g., generated by the `fortune` utility), thereby disrupting the expected termination process and contributing to psychological disorientation.

**Suppression of Standard Login Banners:**
The inclusion of a `.hushlogin` file in the user’s home directory serves to suppress default login messages. This contributes to the illusion of a standard system environment, thereby increasing the likelihood that the honeypot will be perceived as legitimate.

---

```bash
echo "Friday at 10 p.m., I wait at the Blue Oyster. Open a new door." > partkey.txt
openssl genrsa -aes128 -passout pass:BlueOyster -out partkey.pem 2048
openssl rsa -in partkey.pem -passin pass:BlueOyster -pubout -out partkey-pub.pem
openssl rsautl -encrypt -inkey partkey-pub.pem -pubin -in partkey.txt -out partkey.enc
```