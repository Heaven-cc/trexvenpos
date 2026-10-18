import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";
import { loginPermissions } from "../_shared/login-permissions.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function serializeError(error: any) {
  return {
    message: error?.message ?? String(error),
    code: error?.code ?? null,
    details: error?.details ?? null,
    hint: error?.hint ?? null,
    status: error?.status ?? null,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      {
        error: "Method not allowed",
      },
      405,
    );
  }

  try {
    // ============================================================
    // 1. SUPABASE CONFIGURATION
    // ============================================================

    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");

    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        {
          error:
            "Supabase environment variables are not configured",
        },
        500,
      );
    }

    // IMPORTANT:
    // This client uses the service role only inside the Edge Function.
    // Never put the service role key inside Flutter.
    const adminClient = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    // ============================================================
    // 2. READ REQUEST
    // ============================================================

    let body: any;

    try {
      body = await req.json();
    } catch (_) {
      return jsonResponse(
        {
          error: "Invalid request body",
        },
        400,
      );
    }

    const employeeId =
      body?.employee_id?.toString().trim().toUpperCase();

    const password =
      body?.password?.toString();

    if (!employeeId) {
      return jsonResponse(
        {
          error: "Employee ID is required",
        },
        400,
      );
    }

    if (!password) {
      return jsonResponse(
        {
          error: "Password is required",
        },
        400,
      );
    }

    console.log(
      `Employee login attempt: ${employeeId}`,
    );

    // ============================================================
    // 3. FIND EMPLOYEE
    // ============================================================

    const {
      data: employee,
      error: employeeError,
    } = await adminClient
      .from("employees")
      .select(
        `
        id,
        business_id,
        user_id,
        name,
        email,
        phone,
        role,
        employee_code,
        status
        `,
      )
      .eq(
        "employee_code",
        employeeId,
      )
      .maybeSingle();

    if (employeeError) {
      console.error(
        "Employee lookup error:",
        serializeError(employeeError),
      );

      return jsonResponse(
        {
          error: "Unable to verify Employee ID",
        },
        500,
      );
    }

    if (!employee) {
      console.log(
        `Employee not found: ${employeeId}`,
      );

      return jsonResponse(
        {
          error: "Invalid Employee ID or password",
        },
        401,
      );
    }

    // ============================================================
    // 4. CHECK EMPLOYEE STATUS
    // ============================================================

    if (
      employee.status?.toString().toLowerCase() !==
      "active"
    ) {
      return jsonResponse(
        {
          error: "This employee account is inactive",
        },
        403,
      );
    }

    // ============================================================
    // 5. GET EMAIL
    // ============================================================

    let employeeEmail =
      employee.email?.toString().trim().toLowerCase();

    // ------------------------------------------------------------
    // IMPORTANT:
    // Your employees table currently has NULL emails.
    //
    // create-employee generated an internal email when the owner
    // didn't provide one, but that generated email was not stored
    // in employees.email.
    //
    // Therefore we recover it from Supabase Auth using user_id.
    // ------------------------------------------------------------

    if (employee.user_id) {
      const {
        data: authUserData,
        error: authUserError,
      } = await adminClient.auth.admin.getUserById(
        employee.user_id,
      );

      if (!authUserError && authUserData?.user) {
        employeeEmail =
          authUserData.user.email
            ?.toString()
            .trim()
            .toLowerCase();
      }
    }

    if (!employeeEmail) {
      return jsonResponse(
        {
          error:
            "Employee account has no authentication email",
        },
        400,
      );
    }

    console.log(
      `Employee authentication email resolved`,
    );

    // ============================================================
    // 6. VERIFY SUPABASE AUTH USER
    // ============================================================

    if (!employee.user_id) {
      return jsonResponse(
        {
          error:
            "Employee authentication account is not linked",
        },
        400,
      );
    }

    // ============================================================
    // 7. AUTHENTICATE EMPLOYEE
    // ============================================================

    // Use a separate client for sign-in.
    // This prevents the admin client's service-role session
    // from being affected.
    const authClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY") ??
        Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
        "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const {
      data: authData,
      error: signInError,
    } = await authClient.auth.signInWithPassword({
      email: employeeEmail,
      password: password,
    });

    if (signInError || !authData.user) {
      console.log(
        "Authentication failed:",
        signInError
          ? serializeError(signInError)
          : "No authenticated user",
      );

      return jsonResponse(
        {
          error: "Invalid Employee ID or password",
        },
        401,
      );
    }

    // ============================================================
    // 8. VERIFY USER ID
    // ============================================================

    if (
      authData.user.id !==
      employee.user_id
    ) {
      console.error(
        "Auth user does not match employee user_id",
      );

      return jsonResponse(
        {
          error:
            "Employee authentication account mismatch",
        },
        403,
      );
    }

    // ============================================================
    // 9. LOAD BUSINESS
    // ============================================================

    const {
      data: business,
      error: businessError,
    } = await adminClient
      .from("businesses")
      .select("*")
      .eq(
        "id",
        employee.business_id,
      )
      .maybeSingle();

    if (businessError) {
      console.error(
        "Business lookup error:",
        serializeError(businessError),
      );

      return jsonResponse(
        {
          error: "Unable to load business",
        },
        500,
      );
    }

    if (!business) {
      return jsonResponse(
        {
          error:
            "Employee business could not be found",
        },
        404,
      );
    }

    // ============================================================
    // 10. VERIFY BUSINESS MEMBERSHIP
    // ============================================================

    const {
      data: membership,
      error: membershipError,
    } = await adminClient
      .from("business_members")
      .select(
        "id, role, status, permissions",
      )
      .eq(
        "business_id",
        employee.business_id,
      )
      .eq(
        "user_id",
        employee.user_id,
      )
      .maybeSingle();

    if (membershipError) {
      console.error(
        "Membership lookup error:",
        serializeError(membershipError),
      );

      return jsonResponse(
        {
          error:
            "Unable to verify business membership",
        },
        500,
      );
    }

    if (!membership) {
      return jsonResponse(
        {
          error:
            "Employee is not connected to this business",
        },
        403,
      );
    }

    if (
      membership.status?.toString().toLowerCase() !==
      "active"
    ) {
      return jsonResponse(
        {
          error:
            "Employee business membership is inactive",
        },
        403,
      );
    }

    // ============================================================
    // 11. SUCCESS
    // ============================================================

    console.log(
      `Employee login successful: ${employeeId}`,
    );

    const { data: permissionRows, error: permissionError } = await adminClient.from("employee_permissions")
      .select("permission_id,granted").eq("employee_id", employee.id);
    if (permissionError) throw permissionError;
    if (employee.role === 'owner' && business.owner_id !== authData.user.id) {
      return jsonResponse({ error: 'Invalid employee role' }, 403);
    }
    const deniedPermissions = (permissionRows ?? []).filter((row: any) => row.granted === false).map((row: any) => row.permission_id);
    const grantedPermissions = loginPermissions(employee.role,
      (permissionRows ?? []).filter((row: any) => row.granted !== false).map((row: any) => row.permission_id), deniedPermissions);

    return jsonResponse({
      success: true,

      session: {
        access_token:
          authData.session?.access_token ?? null,

        refresh_token:
          authData.session?.refresh_token ?? null,

        expires_in:
          authData.session?.expires_in ?? null,

        expires_at:
          authData.session?.expires_at ?? null,
      },

      employee: {
        denied_permissions: deniedPermissions,
        permissions: grantedPermissions,
        id: employee.id,
        employee_code:
          employee.employee_code,
        name: employee.name,
        email: employee.email,
        phone: employee.phone,
        role: employee.role,
        status: employee.status,
        user_id: employee.user_id,
        business_id:
          employee.business_id,
      },

      business: business,

      membership: {
        id: membership.id,
        role: membership.role,
        status: membership.status,
        permissions:
          membership.permissions ?? {},
      },
    });
  } catch (error) {
    console.error(
      "EMPLOYEE LOGIN ERROR:",
      serializeError(error),
    );

    return jsonResponse(
      {
        error:
          "Unable to complete employee login",
      },
      400,
    );
  }
});
