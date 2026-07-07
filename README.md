# sap-abap-inventory-replenishment
Smart Inventory Replenishment &amp; Alert System with REST API Integration
# Smart Inventory Replenishment & Alert System
 
## Overview
A complete SAP ABAP solution that monitors stock levels across
materials and plants, automatically identifies items falling
below minimum thresholds, sends email alerts, and exposes
all functionality as RESTful HTTP endpoints.
 
## Technology Stack
- SAP ABAP (NetWeaver 7.40)
- SAP ICF (Internet Communication Framework)
- REST API with JSON
- Postman API Client
- CL_BCS Email Framework
- SLG1 Application Logging
- SM36 Background Job Scheduling
- Smartforms with Code 128 Barcode
 
## Project Structure
| Folder       | Contents                          |
|--------------|-----------------------------------|
| src/         | ABAP source code                  |
| table/       | Custom table definitions          |
| smartform/   | Print form structure              |
| postman/     | API collection for testing        |
| docs/        | Project documentation             |
| test/        | Test cases                        |
| screenshots/ | Demo screenshots                  |
 
## Architecture (5 Layers)
1. Data Layer     → ZMAT_STOCK custom table (SE11)
2. Business Logic → ZREPL_CHECK report (SE38)
3. Presentation   → CL_SALV_TABLE ALV with color coding
4. Notification   → CL_BCS email + SLG1 logging
5. API Layer      → ZCL_REPL_HANDLER on SICF node /zrepl
 
## REST API Endpoints
| Method | Endpoint                    | Description              |
|--------|-----------------------------|--------------------------|
| GET    | /zrepl/materials            | All stock records        |
| GET    | /zrepl/materials/alerts     | Below threshold only     |
| GET    | /zrepl/materials/{matnr}    | Single material detail   |
| POST   | /zrepl/materials/replenish  | Confirm replenishment    |
| PUT    | /zrepl/materials/threshold  | Update minimum threshold |
 
## Setup Instructions
1. Create ZMAT_STOCK table in SE11
2. Generate table maintenance via SE54
3. Insert test data via SM30
4. Create ZREPL_CHECK report in SE38
5. Create ZCL_REPL_HANDLER class in SE24
6. Register SICF node /zrepl
7. Create SLGO log object ZREPL
8. Configure SMTP via SCOT
9. Create Smartform ZREPL_ORDER_SF
10. Schedule background job via SM36
 
## Author
- Name  : Hillol
- Sem   : 8th Semester Final Year
- Year  : 2026
