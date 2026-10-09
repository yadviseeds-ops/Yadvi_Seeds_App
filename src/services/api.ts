/**
 * Yadvi Hybrid Seeds - Central API Service
 * Connects React Frontend to FastAPI Backend
 */

export const API_BASE_URL = 'http://localhost:8000/api/v1';

export interface LoginPayload {
  role: string;
  identifier: string;
  password: string;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
  role: string;
  user_id: number;
  full_name: string;
  redirect_path: string;
  metadata?: Record<string, any>;
}

export interface UserProfile {
  id: number;
  full_name: string;
  phone: string;
  email?: string;
  role: string;
  is_active: boolean;
}

class ApiService {
  private getToken(): string | null {
    return localStorage.getItem('yadvi_auth_token');
  }

  public setToken(token: string): void {
    localStorage.setItem('yadvi_auth_token', token);
  }

  public removeToken(): void {
    localStorage.removeItem('yadvi_auth_token');
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = this.getToken();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string> || {}),
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      if (response.status === 401) {
        this.removeToken();
        localStorage.removeItem('yadvi_auth_user');
        window.location.reload();
        throw new Error("Session expired, logging out.");
      }
      let errorMessage = `HTTP Error ${response.status}`;
      try {
        const errorData = await response.json();
        errorMessage = errorData.detail || errorData.message || errorMessage;
      } catch (e) {
        // fallback to status text
        errorMessage = response.statusText || errorMessage;
      }
      throw new Error(errorMessage);
    }

    return response.json() as Promise<T>;
  }

  // Authentication Endpoints
  async requestOtp(username: string, mobile: string): Promise<{message: string, otp_required: boolean}> {
    return this.request<{message: string, otp_required: boolean}>('/auth/request-otp', {
      method: 'POST',
      body: JSON.stringify({ username, mobile }),
    });
  }

  async verifyOtp(username: string, mobile: string, otp: string): Promise<AuthResponse> {
    const data = await this.request<AuthResponse>('/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify({ username, mobile, otp }),
    });
    if (data.access_token) {
      this.setToken(data.access_token);
    }
    return data;
  }

  async getCurrentUser(): Promise<UserProfile> {
    return this.request<UserProfile>('/auth/me');
  }

  async testRoleAccess(roleType: 'admin-only' | 'field-only' | 'shop-only'): Promise<any> {
    return this.request(`/auth/test/${roleType}`);
  }

  // Dashboard
  async getAdminDashboard(): Promise<any> {
    return this.request('/dashboard/admin');
  }

  // Employees
  async getEmployees(): Promise<any[]> {
    return this.request('/employees');
  }
  
  async createEmployee(payload: any): Promise<any> {
    return this.request('/employees', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }
  
  async updateMyLocation(id: number, lat: number, lng: number, battery?: number): Promise<any> {
    return this.request(`/employees/${id}/location`, {
      method: 'PUT',
      body: JSON.stringify({ lat, lng, battery_level: battery }),
    });
  }

  // Orders
  async getOrders(): Promise<any[]> {
    return this.request('/orders');
  }
  
  async createOrder(payload: any): Promise<any> {
    return this.request('/orders', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }
  
  async updateOrderStatus(id: string | number, payload: any): Promise<any> {
    return this.request(`/orders/${id}/status`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
  }

  async assignOrderExecutive(id: string | number, executiveId: number): Promise<any> {
    return this.request(`/orders/${id}/assign-executive`, {
      method: 'PUT',
      body: JSON.stringify({ executive_id: executiveId }),
    });
  }

  // Products
  async getProducts(): Promise<any[]> {
    return this.request('/products');
  }

  async createProduct(payload: any): Promise<any> {
    return this.request('/products', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  // Shops
  async getShops(): Promise<any[]> {
    return this.request('/shops');
  }
  
  async createShop(payload: any): Promise<any> {
    return this.request('/shops', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }
  
  async assignShop(shopId: number, executiveId: number | null): Promise<any> {
    return this.request(`/shops/${shopId}/assign`, {
      method: 'PUT',
      body: JSON.stringify({ executive_id: executiveId }),
    });
  }

  // Attendance
  async getAttendance(): Promise<any[]> {
    return this.request('/attendance');
  }
  
  async checkIn(location: string): Promise<any> {
    return this.request('/attendance/checkin', {
      method: 'POST',
      body: JSON.stringify({ location }),
    });
  }
  
  async checkOut(distance_covered_km: number): Promise<any> {
    return this.request('/attendance/checkout', {
      method: 'POST',
      body: JSON.stringify({ distance_covered_km }),
    });
  }

  // Visits
  async getVisits(): Promise<any[]> {
    return this.request('/visits');
  }
  
  async uploadVisitPhoto(visitId: string | number, lat: number, lng: number, photo_url: string, notes?: string): Promise<any> {
    return this.request(`/visits/${visitId}/upload-photo`, {
      method: 'POST',
      body: JSON.stringify({
        photo_lat: lat,
        photo_lng: lng,
        photo_url,
        notes
      }),
    });
  }

  // Shipments
  async getShipments(): Promise<any[]> {
    return this.request('/shipments');
  }

  // EOD Reports
  async getEodReports(): Promise<any[]> {
    return this.request('/eod');
  }
}

export const api = new ApiService();
