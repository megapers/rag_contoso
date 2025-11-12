# Deploy Frontend to Vercel

This guide walks you through deploying the RAG Contoso frontend to Vercel.

## Prerequisites

- GitHub account (already have the repo)
- Vercel account (sign up at https://vercel.com)

## Quick Deployment Steps

### Option 1: Using Vercel CLI (Fastest)

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel**:
   ```bash
   vercel login
   ```

3. **Deploy from frontend directory**:
   ```bash
   cd frontEnd
   vercel --prod
   ```

4. **Follow the prompts**:
   - Set up and deploy? `Y`
   - Which scope? (select your account)
   - Link to existing project? `N`
   - Project name? `rag-contoso-frontend` (or your choice)
   - In which directory is your code located? `./`
   - Want to override settings? `N`

5. **Set environment variable** (after first deploy):
   ```bash
   vercel env add REACT_APP_API_URL production
   ```
   Then paste: `https://ca-rag-contoso-ws4ty5mcthivw.politecliff-78c46659.eastus.azurecontainerapps.io`

6. **Redeploy with environment variable**:
   ```bash
   vercel --prod
   ```

### Option 2: Using Vercel Dashboard (Easiest)

1. **Go to Vercel**: https://vercel.com/new

2. **Import Git Repository**:
   - Click "Add New..." → "Project"
   - Select your GitHub repository: `megapers/rag_contoso`
   - Click "Import"

3. **Configure Project**:
   - **Framework Preset**: Create React App (should auto-detect)
   - **Root Directory**: Click "Edit" and select `frontEnd`
   - **Build Command**: `npm run build` (default)
   - **Output Directory**: `build` (default)
   - **Install Command**: `npm install` (default)

4. **Add Environment Variable**:
   - Click "Environment Variables"
   - Name: `REACT_APP_API_URL`
   - Value: `https://ca-rag-contoso-ws4ty5mcthivw.politecliff-78c46659.eastus.azurecontainerapps.io`
   - Select all environments (Production, Preview, Development)
   - Click "Add"

5. **Deploy**:
   - Click "Deploy"
   - Wait 1-2 minutes for build to complete

6. **Your app will be live at**: `https://your-project-name.vercel.app`

## Backend CORS Configuration

✅ Already configured! The backend accepts requests from:
- `*.vercel.app` domains
- `localhost` (for development)
- `*.azurecontainerapps.io` domains

## Testing After Deployment

1. Visit your Vercel URL: `https://your-project-name.vercel.app`
2. Try asking: "What were the total sales in 2009?"
3. The app should connect to your Azure backend and show results with charts

## Troubleshooting

### CORS Errors
If you see CORS errors in the browser console:
1. Check that the backend is running: https://ca-rag-contoso-ws4ty5mcthivw.politecliff-78c46659.eastus.azurecontainerapps.io/api/sales
2. Verify the `REACT_APP_API_URL` environment variable in Vercel settings
3. Redeploy after changing environment variables

### 404 Errors on Backend
The backend API endpoints work, but Swagger UI may not be accessible yet. Use these endpoints directly:
- `/api/sales` - Get sales data
- `/api/rag/query` - RAG queries (POST)
- `/api/etl/enrich` - ETL operations (POST)

### Build Failures
If build fails with "out of memory":
1. In Vercel project settings → General
2. Scroll to "Build & Development Settings"
3. Add build command: `CI=false npm run build`

## Automatic Deployments

After initial setup, Vercel automatically deploys:
- **Production**: Every push to `main` branch
- **Preview**: Every pull request

## Free Tier Limits

Vercel Free tier includes:
- ✅ Unlimited deployments
- ✅ 100 GB bandwidth per month
- ✅ Automatic HTTPS
- ✅ Global CDN
- ✅ Serverless functions (not used in this app)

Perfect for demos! 🚀
