import asyncio
import sys

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import httpx

BASE = "http://127.0.0.1:8000/api/v1"


async def main():
    async with httpx.AsyncClient(timeout=20) as c:
        r = await c.post(f"{BASE}/auth/login", json={"mobile_number": "+639900000069", "password": "vendor123"})
        assert r.status_code == 200, r.text
        token = r.json()["access_token"]
        h = {"Authorization": f"Bearer {token}"}
        print("login OK")

        r = await c.get(f"{BASE}/vendor/me", headers=h)
        assert r.status_code == 200, r.text
        me = r.json()
        print(f"vendor/me OK: {me['store_name']} barangays={me['delivery']['delivery_barangays']}")
        print(f"  hours={len(me['hours'])} categories={me['categories']}")

        r = await c.patch(f"{BASE}/vendor/me/status", headers=h, json={"is_open": False})
        assert r.status_code == 200 and r.json()["is_open"] is False, r.text
        r = await c.patch(f"{BASE}/vendor/me/status", headers=h, json={"is_open": True})
        assert r.status_code == 200 and r.json()["is_open"] is True
        print("status toggle OK")

        r = await c.put(f"{BASE}/vendor/me/delivery-settings", headers=h,
                        json={"base_delivery_fee": 35, "delivery_barangays": ["Poblacion", "Naisud"]})
        assert r.status_code == 200 and r.json()["delivery"]["base_delivery_fee"] == 35, r.text
        print("delivery-settings OK")

        r = await c.post(f"{BASE}/vendor/me/menu", headers=h, json={
            "name": "Test Item", "price": 50, "category": "TestCat", "is_featured": False,
            "images": [], "options": [{"group_name": "Extras", "allow_multiple": True,
                                       "choices": [{"label": "Extra Rice", "extra_price": 10}]}],
        })
        assert r.status_code == 201, r.text
        item = r.json()
        print(f"menu create OK: {item['name']} cat={item['category']} options={len(item['options'])}")

        r = await c.patch(f"{BASE}/vendor/me/menu/{item['id']}", headers=h,
                          json={"price": 55, "is_available": False})
        assert r.status_code == 200 and r.json()["price"] == 55 and r.json()["is_available"] is False, r.text
        print("menu update OK")

        r = await c.delete(f"{BASE}/vendor/me/menu/{item['id']}", headers=h)
        assert r.status_code == 204, r.text
        print("menu delete OK")

        r = await c.get(f"{BASE}/vendor/me/analytics", headers=h)
        assert r.status_code == 200, r.text
        a = r.json()
        print(f"analytics OK: today_revenue={a['today_revenue']} week={len(a['week'])} days")

        r = await c.get(f"{BASE}/orders/vendor/inbox", headers=h)
        assert r.status_code == 200, r.text
        print(f"inbox OK: {len(r.json())} orders")

        # customer role must be rejected
        r = await c.post(f"{BASE}/auth/login", json={"mobile_number": "09170000001", "password": "TestPass2"})
        print(f"customer login exists: {r.status_code == 200}")
        if r.status_code == 200:
            ch = {"Authorization": f"Bearer {r.json()['access_token']}"}
            r = await c.get(f"{BASE}/vendor/me", headers=ch)
            assert r.status_code == 403, r.text
            print("customer blocked from vendor portal OK (403)")


asyncio.run(main())
