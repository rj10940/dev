# 🌿 Branch Selection for All Submodules

## ✅ New Feature Added!

You can now **specify different branches** for each micro-frontend when deploying!

---

## 🎯 How It Works

### In GitHub Actions:

When you click "Run workflow", you'll see these inputs:

```
📦 Deployment Configuration:
├─ Deployment name: rahul-feature-123
├─ platformui-frontend branch: master
├─ flexible-ux3 branch: master
├─ fmp-ux3 branch: feature/new-pricing
├─ unified-design-system branch: develop
├─ agencyos-ux3 branch: master
├─ guests-app-ux3 branch: main
└─ Auto-destroy: 7 days
```

---

## 📋 Use Cases

### Use Case 1: Test a Single Submodule Feature

```
Scenario: You made changes in flexible-ux3 only

Configuration:
- platformui-frontend: master
- flexible-ux3: feature/new-ui ← Your feature branch
- fmp-ux3: master
- unified-design-system: master
- agencyos-ux3: master
- guests-app-ux3: master

Result: Tests your flexible-ux3 changes with all other stable versions
```

### Use Case 2: Test Multiple Features Together

```
Scenario: Testing design system + flexible changes together

Configuration:
- platformui-frontend: master
- flexible-ux3: feature/new-buttons
- fmp-ux3: master
- unified-design-system: feature/button-redesign ← Coordinated
- agencyos-ux3: master
- guests-app-ux3: master

Result: Tests both feature branches together
```

### Use Case 3: Full Feature Branch Deployment

```
Scenario: Major feature affecting multiple apps

Configuration:
- platformui-frontend: feature/dashboard-v2
- flexible-ux3: feature/dashboard-v2
- fmp-ux3: feature/dashboard-v2
- unified-design-system: feature/dashboard-v2
- agencyos-ux3: feature/dashboard-v2
- guests-app-ux3: master

Result: All related changes deployed together
```

### Use Case 4: Staging/Pre-prod Testing

```
Scenario: Test develop/staging branches before production

Configuration:
- platformui-frontend: develop
- flexible-ux3: develop
- fmp-ux3: staging
- unified-design-system: develop
- agencyos-ux3: develop
- guests-app-ux3: staging

Result: Test pre-release versions
```

---

## 🚀 How to Use

### Via GitHub Actions:

1. Go to **Actions** → "🚀 Deploy ODS Frontend"
2. Click **"Run workflow"**
3. Fill in deployment name and **all branch names**:
   ```
   Deployment name: rahul-test-ui
   platformui-frontend: master
   flexible-ux3: feature/new-ui
   fmp-ux3: master
   unified-design-system: develop
   agencyos-ux3: master
   guests-app-ux3: master
   ```
4. Click **"Run workflow"**
5. Access: `https://rahul-test-ui.ods.rahuljoshi.info`

### Via SSH (Advanced):

```bash
ssh root@64.227.159.162
cd /opt/ods-deployments

./scripts/deploy-frontend.sh deploy \
  rahul-test \
  master \                    # platformui-frontend
  rahul \                     # owner
  7 \                         # auto-destroy days
  feature/new-ui \            # flexible-ux3
  master \                    # fmp-ux3
  develop \                   # unified-design-system
  master \                    # agencyos-ux3
  master                      # guests-app-ux3
```

---

## 📝 Default Behavior

If you **don't specify** a branch, it defaults to `master`:

```
Input: (empty)
Used: master
```

So you can still leave fields empty and it will work with master branches!

---

## 🔍 Verification

After deployment, check which branches were used:

### In GitHub Actions Summary:

```
📦 Branches Deployed:
- platformui-frontend: master
- flexible-ux3: feature/new-ui
- fmp-ux3: master
- unified-design-system: develop
- agencyos-ux3: master
- guests-app-ux3: master
```

### In VPS Logs:

```bash
ssh root@64.227.159.162
cd /opt/ods-deployments
./scripts/deploy-frontend.sh list
```

---

## ⚠️ Important Notes

1. **Branch must exist** in the repository
   - If branch doesn't exist, it will fallback to master/main

2. **All submodules are updated** sequentially
   - No parallel operations (Ubuntu-compatible)

3. **Build uses platformui-frontend's .env**
   - All micro-frontends still point to rj8-dev-ux.cloudways.services

4. **Independent versioning**
   - Each submodule can be on different branch
   - No dependency conflicts between submodule versions

---

## 🎉 Benefits

✅ **Flexible testing** - Test any combination of branches
✅ **No code changes** - Use existing branches as-is
✅ **Safe defaults** - master branch if not specified
✅ **Clear documentation** - See exactly which branches were deployed
✅ **Easy rollback** - Deploy again with different branches
✅ **Team collaboration** - Multiple developers can test different combos

---

## 📚 Examples

### Example 1: Quick Master Deployment
```
Just specify deployment name, leave all branches as "master"
Result: All stable versions deployed
```

### Example 2: Feature Testing
```
Change ONE branch to your feature
Leave others as "master"
Result: Your feature with stable dependencies
```

### Example 3: Integration Testing
```
Change multiple related branches
Result: Test feature integration
```

---

**Happy deploying with branch flexibility!** 🚀
