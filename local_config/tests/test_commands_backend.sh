# Backend
sudo systemctl status anime-review-api
sudo systemctl is-enabled anime-review-api
sudo journalctl -u anime-review-api -n 50 --no-pager

curl http://localhost:3001/health
curl http://localhost:3001/ready

sudo ss -lntp | grep 3001